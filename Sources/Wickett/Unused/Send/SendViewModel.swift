import Foundation
import SwiftUI

/// ViewModel for handling send transaction flow
/// Integrates with V2 backend functions and Privy signing
@MainActor
class SendViewModel: ObservableObject {
    // MARK: - Published State

    @Published var recipientAddress = ""
    @Published var selectedRecipient: RecentRecipient?
    @Published var usdAmount = ""
    @Published var cryptoAmount = ""
    @Published var memo = ""
    @Published var selectedToken: SolanaToken = TokenRegistry.USDC {
        didSet {
            // Remember last used token
            UserDefaults.standard.set(selectedToken.symbol, forKey: "lastUsedTokenSymbol")
        }
    }

    @Published var isLoading = false
    @Published var transactionState: TransactionState = .idle
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var transactionSignature: String?

    // Recent Recipients
    @Published var recentRecipients: [RecentRecipient] = []
    @Published var isLoadingRecipients = true
    private let recipientsService = RecentRecipientsService.shared

    // Search State
    @Published var searchResults: [UserSearchResult] = []
    @Published var isSearching = false
    private let requestService = RequestService.shared
    private var searchTask: Task<Void, Never>?

    /// Suggested recipients sorted by frequency (most sent to first)
    var suggestedRecipients: [RecentRecipient] {
        recentRecipients
            .sorted { $0.frequency > $1.frequency }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Dependencies

    private let firebaseClient = FirebaseCallableClient.shared
    let walletService = SolanaWalletService.shared
    private let signingService = SolanaSigningService.shared
    private let activityService = ActivityService.shared

    // MARK: - Current User

    var userWalletAddress: String?

    init(userWalletAddress: String?) {
        self.userWalletAddress = userWalletAddress

        // Restore last used token from UserDefaults
        if let lastTokenSymbol = UserDefaults.standard.string(forKey: "lastUsedTokenSymbol"),
           let lastToken = TokenRegistry.allTokens.first(where: { $0.symbol == lastTokenSymbol }) {
            selectedToken = lastToken
        }

        // Auto-select first token with balance if current selection has no balance
        if let balance = self.availableBalance, balance.lamports == 0 {
            if let tokenWithBalance = self.walletService.balances.first(where: { $0.hasBalance }) {
                self.selectedToken = tokenWithBalance.token
            }
        }

        // Fetch recent recipients
        Task {
            if let wallet = userWalletAddress {
                await recipientsService.fetchRecentRecipients(userId: wallet)
                recentRecipients = recipientsService.recentRecipients
            }
            isLoadingRecipients = false
        }
    }

    // MARK: - Computed Properties

    /// Available balance for selected token
    var availableBalance: TokenBalance? {
        walletService.balances.first { $0.token.symbol == selectedToken.symbol }
    }

    /// Display formatted available balance
    var displayAvailableBalance: String {
        guard let balance = availableBalance else {
            return "0 \(selectedToken.symbol)"
        }
        return balance.displayAmount
    }

    /// Parsed amount in lamports (uses crypto amount)
    var amountInLamports: UInt64? {
        guard let decimalAmount = Decimal(string: cryptoAmount) else { return nil }
        return selectedToken.toLamports(decimalAmount)
    }

    /// Current USD price for selected token
    var currentUSDPrice: Decimal {
        availableBalance?.usdPrice ?? 0
    }

    /// Whether send button should be enabled
    var canSend: Bool {
        guard !recipientAddress.isEmpty,
              !cryptoAmount.isEmpty,
              let lamports = amountInLamports,
              !isLoading,
              transactionState == .idle else {
            return false
        }

        // Check if user has sufficient balance
        guard let balance = availableBalance else {
            return false
        }

        // For SOL, need to account for transaction fee
        if selectedToken.symbol == "SOL" {
            let estimatedFeeLamports: UInt64 = 5000
            return balance.lamports >= (lamports + estimatedFeeLamports)
        } else {
            // For SPL tokens, just check if amount <= balance
            return balance.lamports >= lamports
        }
    }

    /// Display text for send button
    var sendButtonText: String {
        if isLoading {
            return "Sending..."
        }

        if !usdAmount.isEmpty, let decimal = Decimal(string: usdAmount) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 2

            if let formatted = formatter.string(from: decimal as NSDecimalNumber) {
                if let recipient = selectedRecipient, let name = recipient.displayName {
                    return "Pay \(formatted) to \(name)"
                }
                return "Pay \(formatted)"
            }
        }

        return "Pay"
    }

    /// Error display message
    var displayError: String? {
        errorMessage
    }

    // MARK: - Public Methods

    /// Validate input and initiate send transaction
    func sendTransaction() async {
        guard let userWallet = userWalletAddress else {
            setError("User wallet address not found")
            return
        }

        guard let lamports = amountInLamports else {
            setError("Invalid amount")
            return
        }

        // Check sufficient balance
        guard let balance = availableBalance else {
            setError("Unable to check balance")
            return
        }

        // Verify sufficient balance (including fee for SOL)
        if selectedToken.symbol == "SOL" {
            let estimatedFeeLamports: UInt64 = 5000
            guard balance.lamports >= (lamports + estimatedFeeLamports) else {
                setError("Insufficient balance. You need at least \(selectedToken.fromLamports(lamports + estimatedFeeLamports)) SOL (including transaction fee)")
                return
            }
        } else {
            guard balance.lamports >= lamports else {
                setError("Insufficient balance. You have \(balance.displayAmount) available")
                return
            }
        }

        // Reset state
        errorMessage = nil
        successMessage = nil
        transactionSignature = nil
        isLoading = true
        transactionState = .building

        do {
            // Step 1: Build partial transaction
            let partialTx = try await buildPartialTransaction(
                recipientAddress: recipientAddress,
                amount: lamports,
                userWallet: userWallet
            )

            // Step 2: Sign with user's wallet via Privy
            let signedTx = try await signTransaction(partialTx: partialTx, userWallet: userWallet)

            // Step 3: Broadcast signed transaction
            // Note: Backend already waits for "confirmed" commitment before returning
            let signature = try await broadcastTransaction(signedTx: signedTx)

            // Transaction is already confirmed by backend
            transactionSignature = signature
            successMessage = "Transaction sent successfully!"
            transactionState = .completed
            isLoading = false

            // Refresh wallet balances and activity feed (transaction already confirmed on-chain)
            await walletService.refreshBalances(walletAddress: userWallet)
            await activityService.refresh()

        } catch {
            setError(error.localizedDescription)
            transactionState = .failed
            isLoading = false
        }
    }

    /// Set maximum amount (use all available balance)
    func setMaxAmount() {
        guard let balance = availableBalance else { return }

        // For SOL, subtract estimated fee (~0.000005 SOL)
        let estimatedFeeLamports: UInt64 = 5000

        let maxAmount: Decimal
        if selectedToken.symbol == "SOL" {
            if balance.lamports > estimatedFeeLamports {
                let maxLamports = balance.lamports - estimatedFeeLamports
                maxAmount = selectedToken.fromLamports(maxLamports)
            } else {
                maxAmount = 0
            }
        } else {
            // For SPL tokens, can send full balance
            maxAmount = selectedToken.fromLamports(balance.lamports)
        }

        // Set crypto amount with POSIX locale formatter
        let cryptoFormatter = NumberFormatter()
        cryptoFormatter.locale = Locale(identifier: "en_US_POSIX")
        cryptoFormatter.numberStyle = .decimal
        cryptoFormatter.maximumFractionDigits = selectedToken.decimals
        cryptoFormatter.minimumFractionDigits = 0
        cryptoFormatter.usesGroupingSeparator = false
        cryptoAmount = cryptoFormatter.string(from: maxAmount as NSDecimalNumber) ?? "0"

        // Calculate and set USD amount
        if balance.usdPrice > 0 {
            let usdValue = maxAmount * balance.usdPrice
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2

            if let formatted = formatter.string(from: usdValue as NSDecimalNumber) {
                usdAmount = formatted
            }
        }
    }

    /// Clear all form data
    func clearForm() {
        recipientAddress = ""
        usdAmount = ""
        cryptoAmount = ""
        memo = ""
        errorMessage = nil
        successMessage = nil
        transactionSignature = nil
        transactionState = .idle
    }

    // MARK: - Search Methods

    /// Search for users by username, name, or wallet address with debouncing
    func searchUsers(query: String) {
        // Cancel any existing search task
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear results if query is too short
        guard trimmedQuery.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        // Debounce search by 300ms
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms

                // Check if task was cancelled during sleep
                guard !Task.isCancelled else { return }

                let results = try await requestService.searchUsers(query: trimmedQuery, limit: 10)

                // Check if task was cancelled after search
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }

    /// Clear search results
    func clearSearch() {
        searchTask?.cancel()
        searchResults = []
        isSearching = false
    }

    // MARK: - Private Methods

    /// Step 1: Call backend to build partial transaction
    private func buildPartialTransaction(
        recipientAddress: String,
        amount: UInt64,
        userWallet: String
    ) async throws -> String {
        transactionState = .building

        let functionName: String
        let data: [String: Any]

        if selectedToken.symbol == "SOL" {
            // SOL transfer
            functionName = "sponsorSolTransferV2"
            data = [
                "destinationAddress": recipientAddress,
                "amountLamports": amount,
                "userWalletAddress": userWallet,
                "memo": memo.isEmpty ? nil : memo
            ].compactMapValues { $0 }
        } else {
            // SPL token transfer
            guard let mint = selectedToken.mint else {
                throw SendError.invalidToken
            }

            functionName = "sponsorSplTransferV2"
            data = [
                "tokenMintAddress": mint,
                "destinationAddress": recipientAddress,
                "amount": amount,
                "decimals": selectedToken.decimals,
                "userWalletAddress": userWallet,
                "memo": memo.isEmpty ? nil : memo
            ].compactMapValues { $0 }
        }

        let result = try await firebaseClient.call(functionName, data: data)

        // Parse response - backend returns { success: true, data: { partiallySignedTransaction, estimatedFee } }
        guard let resultData = result.data as? [String: Any],
              let success = resultData["success"] as? Bool,
              success else {
            let error = (result.data as? [String: Any])?["error"] as? String ?? "Failed to build transaction"
            throw SendError.buildFailed(error)
        }

        guard let responseData = resultData["data"] as? [String: Any],
              let partialTx = responseData["partiallySignedTransaction"] as? String else {
            throw SendError.buildFailed("Invalid response format - missing transaction data")
        }

        return partialTx
    }

    /// Step 2: Sign transaction with user's private key via Privy
    private func signTransaction(partialTx: String, userWallet: String) async throws -> String {
        transactionState = .signing
        return try await signingService.signTransaction(partialTx)
    }

    /// Step 3: Broadcast signed transaction to network
    private func broadcastTransaction(signedTx: String) async throws -> String {

        transactionState = .broadcasting

        // Calculate USD amount for activity tracking
        let amountUsd: Double
        if let usdValue = Decimal(string: usdAmount) {
            amountUsd = NSDecimalNumber(decimal: usdValue).doubleValue
        } else {
            amountUsd = 0
        }

        // Get recipient display name
        let recipientDisplay = selectedRecipient?.displayName ?? selectedRecipient?.formattedAddress

        let data: [String: Any] = [
            "signedTransaction": signedTx,  // Now a fully-signed VersionedTransaction
            "transactionType": selectedToken.symbol == "SOL" ? "sol_transfer" : "spl_transfer",
            "recipientAddress": recipientAddress,
            "amountUsd": amountUsd,
            "recipientDisplay": recipientDisplay as Any
        ].compactMapValues { $0 }

        let result = try await firebaseClient.call("broadcastSignedTransaction", data: data)

        // Parse response - backend returns { success: true, data: { transactionHash, explorerUrl } }
        guard let resultData = result.data as? [String: Any],
              let success = resultData["success"] as? Bool,
              success else {
            let error = (result.data as? [String: Any])?["error"] as? String ?? "Failed to broadcast transaction"
            throw SendError.broadcastFailed(error)
        }

        guard let responseData = resultData["data"] as? [String: Any],
              let signature = responseData["transactionHash"] as? String else {
            throw SendError.broadcastFailed("Invalid response format - missing transaction hash")
        }

        return signature
    }

    /// Set error message
    private func setError(_ message: String) {
        errorMessage = message
    }
}

// MARK: - Send Errors

enum SendError: LocalizedError {
    case invalidToken
    case buildFailed(String)
    case signingFailed(String)
    case broadcastFailed(String)
    case insufficientBalance
    case invalidAddress

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid token selected"
        case .buildFailed(let message):
            return "Failed to build transaction: \(message)"
        case .signingFailed(let message):
            return "Failed to sign transaction: \(message)"
        case .broadcastFailed(let message):
            return "Failed to broadcast transaction: \(message)"
        case .insufficientBalance:
            return "Insufficient balance for this transaction"
        case .invalidAddress:
            return "Invalid recipient address"
        }
    }
}
