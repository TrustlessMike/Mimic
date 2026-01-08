import Foundation
import PrivySDK
import SolanaSwift
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "SolanaSigningService")

/// Service for signing Solana transactions using Privy embedded wallet
@MainActor
class SolanaSigningService {
    static let shared = SolanaSigningService()

    private let hybridPrivyService = HybridPrivyService.shared

    private init() {
        logger.info("✅ SolanaSigningService initialized")
    }

    // MARK: - Public API

    /// Sign a partially-signed Solana transaction with the user's embedded wallet
    /// - Parameter partialTransaction: Base64-encoded partial transaction (with fee payer signature only)
    /// - Returns: Base64-encoded fully-signed transaction (with both fee payer and user signatures)
    func signTransaction(_ partialTransaction: String) async throws -> String {
        do {
            // Deserialize the partial transaction
            guard let transactionData = Data(base64Encoded: partialTransaction) else {
                throw SolanaSigningError.invalidTransaction
            }

            let versionedTransaction = try VersionedTransaction.deserialize(data: transactionData)

            // Extract the message to sign
            let messageData: Data
            switch versionedTransaction.message {
            case .legacy(let legacyMessage):
                messageData = Data(try legacyMessage.serialize())
            case .v0(let messageV0):
                messageData = Data(try messageV0.serialize())
            }

            let messageToSign = messageData.base64EncodedString()

            // Sign the message with Privy
            let signingResult = try await hybridPrivyService.signMessageForSponsorship(messageToSign)

            // Add the user signature to the transaction
            var completeTransaction = versionedTransaction
            let userPublicKey = try PublicKey(string: signingResult.walletAddress)
            guard let signatureData = Data(base64Encoded: signingResult.signature) else {
                throw SolanaSigningError.invalidSignature
            }

            try completeTransaction.addSignature(publicKey: userPublicKey, signature: signatureData)

            // Serialize the fully-signed transaction
            let signedTransactionData = Data(try completeTransaction.serialize())
            return signedTransactionData.base64EncodedString()

        } catch let error as SolanaSigningError {
            logger.error("❌ Transaction signing failed: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("❌ Transaction signing failed: \(error.localizedDescription)")
            throw SolanaSigningError.signingFailed(error.localizedDescription)
        }
    }

    /// Sign an unsigned Solana transaction (for Jupiter Ultra API)
    /// - Parameter unsignedTransaction: Base64-encoded unsigned transaction
    /// - Returns: Base64-encoded signed transaction
    func signUnsignedTransaction(_ unsignedTransaction: String) async throws -> String {
        do {
            // Deserialize the unsigned transaction
            guard let transactionData = Data(base64Encoded: unsignedTransaction) else {
                throw SolanaSigningError.invalidTransaction
            }

            var versionedTransaction = try VersionedTransaction.deserialize(data: transactionData)

            // Extract the message to sign
            let messageData: Data
            switch versionedTransaction.message {
            case .legacy(let legacyMessage):
                messageData = Data(try legacyMessage.serialize())
            case .v0(let messageV0):
                messageData = Data(try messageV0.serialize())
            }

            let messageToSign = messageData.base64EncodedString()
            logger.info("📝 Signing unsigned transaction message...")

            // Sign the message with Privy
            let signingResult = try await hybridPrivyService.signMessageForSponsorship(messageToSign)
            logger.info("✅ Got signature from Privy for wallet: \(signingResult.walletAddress)")

            // Add the user signature to the transaction at the first position (fee payer)
            let userPublicKey = try PublicKey(string: signingResult.walletAddress)
            guard let signatureData = Data(base64Encoded: signingResult.signature) else {
                throw SolanaSigningError.invalidSignature
            }

            // For unsigned transactions, we need to set the signature at the correct index
            try versionedTransaction.addSignature(publicKey: userPublicKey, signature: signatureData)

            // Serialize the signed transaction
            let signedTransactionData = Data(try versionedTransaction.serialize())
            logger.info("✅ Transaction signed successfully")
            return signedTransactionData.base64EncodedString()

        } catch let error as SolanaSigningError {
            logger.error("❌ Transaction signing failed: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("❌ Transaction signing failed: \(error.localizedDescription)")
            throw SolanaSigningError.signingFailed(error.localizedDescription)
        }
    }

}

// MARK: - Errors

enum SolanaSigningError: LocalizedError {
    case userNotAuthenticated
    case noSolanaWallet
    case providerNotAvailable
    case signingFailed(String)
    case invalidTransaction
    case invalidSignature

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "Please sign in to continue"
        case .noSolanaWallet:
            return "No Solana wallet found. Please create a wallet first."
        case .providerNotAvailable:
            return "Unable to access wallet provider"
        case .signingFailed(let message):
            return "Transaction signing failed: \(message)"
        case .invalidTransaction:
            return "Invalid transaction format"
        case .invalidSignature:
            return "Invalid signature format"
        }
    }
}
