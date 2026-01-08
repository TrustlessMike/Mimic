import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "CopyTrading")

/// Tracked wallet for copy trading
struct TrackedWallet: Identifiable, Codable {
    let id: String
    let userId: String
    let walletAddress: String
    var nickname: String?
    var autoCopyEnabled: Bool
    var executionMode: ExecutionMode
    var stats: TrackedWalletStats
    let createdAt: Date

    enum ExecutionMode: String, Codable, CaseIterable {
        case manual = "manual"
        case immediate = "immediate"

        var displayName: String {
            switch self {
            case .manual: return "Manual"
            case .immediate: return "Auto"
            }
        }

        var description: String {
            switch self {
            case .manual: return "Get notified, copy manually"
            case .immediate: return "Copy trades automatically"
            }
        }
    }

    struct TrackedWalletStats: Codable {
        var totalTrades: Int
        var winRate: Double
        var pnl: Double
        var lastTradeAt: Date?
    }
}

/// Copy trading configuration for a user
struct CopyTradingConfig: Codable {
    var copyPercentage: Double  // % of portfolio per copy (e.g., 0.05 = 5%)
    var maxCopyAmountUsd: Double // Max USD per trade
    var dailyLimitUsd: Double   // Daily spending limit
    var safeMode: Bool          // Only major tokens

    static var `default`: CopyTradingConfig {
        CopyTradingConfig(
            copyPercentage: 0.05,  // 5%
            maxCopyAmountUsd: 50,
            dailyLimitUsd: 200,
            safeMode: true
        )
    }
}

/// Service for managing copy trading
@MainActor
class CopyTradingService: ObservableObject {
    static let shared = CopyTradingService()

    private let db = Firestore.firestore()
    private let firebaseClient = FirebaseCallableClient.shared

    @Published var trackedWallets: [TrackedWallet] = []
    @Published var copyConfig: CopyTradingConfig = .default
    @Published var isLoading = false
    @Published var error: String?
    @Published var delegationActive = false

    private var walletsListener: ListenerRegistration?

    private init() {}

    deinit {
        walletsListener?.remove()
    }

    // MARK: - Load Tracked Wallets

    func loadTrackedWallets() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isLoading = true
        error = nil

        do {
            let snapshot = try await db.collection("tracked_wallets")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            trackedWallets = snapshot.documents.compactMap { doc in
                parseTrackedWallet(doc)
            }

            logger.info("Loaded \(self.trackedWallets.count) tracked wallets")
        } catch {
            logger.error("Failed to load tracked wallets: \(error.localizedDescription)")
            self.error = "Failed to load tracked wallets"
        }

        isLoading = false
    }

    /// Start real-time listener for tracked wallets
    func startWalletsListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        walletsListener?.remove()

        walletsListener = db.collection("tracked_wallets")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    logger.error("Wallets listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    self.trackedWallets = documents.compactMap { doc in
                        self.parseTrackedWallet(doc)
                    }
                }
            }
    }

    func stopWalletsListener() {
        walletsListener?.remove()
        walletsListener = nil
    }

    // MARK: - Add/Remove Tracked Wallet

    func addTrackedWallet(address: String, nickname: String?) async throws {
        isLoading = true
        error = nil

        do {
            let result = try await firebaseClient.call("addTrackedWallet", data: [
                "walletAddress": address,
                "nickname": nickname ?? ""
            ])

            if let response = result.data as? [String: Any],
               let success = response["success"] as? Bool,
               success {
                logger.info("Added tracked wallet: \(address)")
                await loadTrackedWallets()
            } else {
                throw CopyTradingError.addFailed
            }
        } catch {
            logger.error("Failed to add tracked wallet: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }

        isLoading = false
    }

    func removeTrackedWallet(_ wallet: TrackedWallet) async throws {
        isLoading = true
        error = nil

        do {
            let result = try await firebaseClient.call("removeTrackedWallet", data: [
                "trackedWalletId": wallet.id,
                "walletAddress": wallet.walletAddress
            ])

            if let response = result.data as? [String: Any],
               let success = response["success"] as? Bool,
               success {
                logger.info("Removed tracked wallet: \(wallet.walletAddress)")
                trackedWallets.removeAll { $0.id == wallet.id }
            } else {
                throw CopyTradingError.removeFailed
            }
        } catch {
            logger.error("Failed to remove tracked wallet: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }

        isLoading = false
    }

    // MARK: - Toggle Auto-Copy

    func toggleAutoCopy(for wallet: TrackedWallet, enabled: Bool) async {
        guard let index = trackedWallets.firstIndex(where: { $0.id == wallet.id }) else { return }

        do {
            try await db.collection("tracked_wallets").document(wallet.id).updateData([
                "autoCopyEnabled": enabled,
                "updatedAt": FieldValue.serverTimestamp()
            ])

            trackedWallets[index].autoCopyEnabled = enabled
            logger.info("Auto-copy \(enabled ? "enabled" : "disabled") for \(wallet.walletAddress)")
        } catch {
            logger.error("Failed to toggle auto-copy: \(error.localizedDescription)")
            self.error = "Failed to update auto-copy setting"
        }
    }

    func setExecutionMode(for wallet: TrackedWallet, mode: TrackedWallet.ExecutionMode) async {
        guard let index = trackedWallets.firstIndex(where: { $0.id == wallet.id }) else { return }

        do {
            try await db.collection("tracked_wallets").document(wallet.id).updateData([
                "executionMode": mode.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])

            trackedWallets[index].executionMode = mode
            logger.info("Execution mode set to \(mode.rawValue) for \(wallet.walletAddress)")
        } catch {
            logger.error("Failed to set execution mode: \(error.localizedDescription)")
            self.error = "Failed to update execution mode"
        }
    }

    // MARK: - Copy Trading Config

    func loadCopyConfig() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            let doc = try await db.collection("users").document(userId).getDocument()

            if let data = doc.data(),
               let configData = data["copyTradingConfig"] as? [String: Any] {
                copyConfig = CopyTradingConfig(
                    copyPercentage: configData["copyPercentage"] as? Double ?? 0.05,
                    maxCopyAmountUsd: configData["maxCopyAmountUsd"] as? Double ?? 50,
                    dailyLimitUsd: configData["dailyLimitUsd"] as? Double ?? 200,
                    safeMode: configData["safeMode"] as? Bool ?? true
                )
            }
        } catch {
            logger.error("Failed to load copy config: \(error.localizedDescription)")
        }
    }

    func saveCopyConfig() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(userId).setData([
                "copyTradingConfig": [
                    "copyPercentage": copyConfig.copyPercentage,
                    "maxCopyAmountUsd": copyConfig.maxCopyAmountUsd,
                    "dailyLimitUsd": copyConfig.dailyLimitUsd,
                    "safeMode": copyConfig.safeMode
                ],
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            logger.info("Saved copy trading config")
        } catch {
            logger.error("Failed to save copy config: \(error.localizedDescription)")
            self.error = "Failed to save settings"
        }
    }

    // MARK: - Delegation Status

    func checkDelegationStatus() async {
        do {
            let result = try await firebaseClient.call("getDelegationStatus", data: [:])

            if let response = result.data as? [String: Any],
               let isActive = response["isActive"] as? Bool {
                delegationActive = isActive
            }
        } catch {
            logger.error("Failed to check delegation status: \(error.localizedDescription)")
            delegationActive = false
        }
    }

    func enableDelegation() async throws {
        let result = try await firebaseClient.call("approveDelegationV2", data: [:])

        if let response = result.data as? [String: Any],
           let success = response["success"] as? Bool,
           success {
            delegationActive = true
            logger.info("Delegation enabled")
        } else {
            throw CopyTradingError.delegationFailed
        }
    }

    func revokeDelegation() async throws {
        let result = try await firebaseClient.call("revokeDelegationV2", data: [:])

        if let response = result.data as? [String: Any],
           let success = response["success"] as? Bool,
           success {
            delegationActive = false
            logger.info("Delegation revoked")
        } else {
            throw CopyTradingError.revokeFailed
        }
    }

    // MARK: - Parsing

    private func parseTrackedWallet(_ doc: DocumentSnapshot) -> TrackedWallet? {
        let data = doc.data() ?? [:]

        guard let userId = data["userId"] as? String,
              let walletAddress = data["walletAddress"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let statsData = data["stats"] as? [String: Any] ?? [:]
        var lastTradeAt: Date?
        if let timestamp = statsData["lastTradeAt"] as? Timestamp {
            lastTradeAt = timestamp.dateValue()
        }

        let stats = TrackedWallet.TrackedWalletStats(
            totalTrades: statsData["totalTrades"] as? Int ?? 0,
            winRate: statsData["winRate"] as? Double ?? 0,
            pnl: statsData["pnl"] as? Double ?? 0,
            lastTradeAt: lastTradeAt
        )

        let executionModeStr = data["executionMode"] as? String ?? "manual"
        let executionMode = TrackedWallet.ExecutionMode(rawValue: executionModeStr) ?? .manual

        return TrackedWallet(
            id: doc.documentID,
            userId: userId,
            walletAddress: walletAddress,
            nickname: data["nickname"] as? String,
            autoCopyEnabled: data["autoCopyEnabled"] as? Bool ?? false,
            executionMode: executionMode,
            stats: stats,
            createdAt: createdAt
        )
    }
}

// MARK: - Errors

enum CopyTradingError: LocalizedError {
    case addFailed
    case removeFailed
    case delegationFailed
    case revokeFailed

    var errorDescription: String? {
        switch self {
        case .addFailed: return "Failed to add wallet"
        case .removeFailed: return "Failed to remove wallet"
        case .delegationFailed: return "Failed to enable copy trading"
        case .revokeFailed: return "Failed to disable copy trading"
        }
    }
}
