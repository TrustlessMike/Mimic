import Foundation
import OSLog

/// Service for wallet tracking and trade feed
@MainActor
class TrackingService: ObservableObject {
    static let shared = TrackingService()

    private let logger = Logger(subsystem: "com.mimic.app", category: "TrackingService")
    private let firebaseClient = FirebaseCallableClient.shared

    @Published var trackedWallets: [TrackedWallet] = []
    @Published var tradeFeed: [TrackedTrade] = []
    @Published var isLoadingWallets = false
    @Published var isLoadingFeed = false
    @Published var errorMessage: String?

    private var feedNextCursor: String?
    private var hasMoreFeed = true

    private init() {}

    // MARK: - Tracked Wallets

    /// Load user's tracked wallets
    func loadTrackedWallets() async {
        guard !isLoadingWallets else { return }

        isLoadingWallets = true
        errorMessage = nil

        do {
            let result: GetTrackedWalletsResponse = try await firebaseClient.call(
                function: "getTrackedWallets",
                data: [:]
            )

            if result.success {
                trackedWallets = result.wallets
                logger.info("✅ Loaded \(result.count) tracked wallets")
            }
        } catch {
            logger.error("❌ Failed to load tracked wallets: \(error.localizedDescription)")
            errorMessage = "Failed to load tracked wallets"
        }

        isLoadingWallets = false
    }

    /// Add a wallet to track
    func addTrackedWallet(address: String, nickname: String?) async throws -> TrackedWallet {
        logger.info("📡 Adding tracked wallet: \(address)")

        let result: AddTrackedWalletResponse = try await firebaseClient.call(
            function: "addTrackedWallet",
            data: [
                "walletAddress": address,
                "nickname": nickname as Any,
            ]
        )

        guard result.success, let wallet = result.trackedWallet else {
            throw TrackingError.failedToAdd
        }

        // Reload wallets to get full data
        await loadTrackedWallets()

        logger.info("✅ Wallet tracked: \(address)")
        return wallet
    }

    /// Remove a tracked wallet
    func removeTrackedWallet(id: String) async throws {
        logger.info("🗑️ Removing tracked wallet: \(id)")

        let result: BasicResponse = try await firebaseClient.call(
            function: "removeTrackedWallet",
            data: ["trackedWalletId": id]
        )

        guard result.success else {
            throw TrackingError.failedToRemove
        }

        // Remove from local list
        trackedWallets.removeAll { $0.id == id }

        logger.info("✅ Wallet removed")
    }

    // MARK: - Trade Feed

    /// Load trade feed from tracked wallets
    func loadTradeFeed(filter: TradeFeedFilter = .all, refresh: Bool = false) async {
        guard !isLoadingFeed else { return }

        if refresh {
            feedNextCursor = nil
            hasMoreFeed = true
            tradeFeed = []
        }

        guard hasMoreFeed else { return }

        isLoadingFeed = true
        errorMessage = nil

        do {
            var data: [String: Any] = [
                "limit": 20,
                "filter": filter.rawValue,
            ]

            if let cursor = feedNextCursor {
                data["startAfter"] = cursor
            }

            let result: GetTradeFeedResponse = try await firebaseClient.call(
                function: "getTradeFeed",
                data: data
            )

            if result.success {
                if refresh {
                    tradeFeed = result.trades
                } else {
                    tradeFeed.append(contentsOf: result.trades)
                }

                feedNextCursor = result.nextCursor
                hasMoreFeed = result.hasMore

                logger.info("✅ Loaded \(result.trades.count) trades, hasMore: \(result.hasMore)")
            }
        } catch {
            logger.error("❌ Failed to load trade feed: \(error.localizedDescription)")
            errorMessage = "Failed to load trade feed"
        }

        isLoadingFeed = false
    }

    /// Load more trades (pagination)
    func loadMoreTrades(filter: TradeFeedFilter = .all) async {
        await loadTradeFeed(filter: filter, refresh: false)
    }

    /// Refresh trade feed
    func refreshFeed(filter: TradeFeedFilter = .all) async {
        await loadTradeFeed(filter: filter, refresh: true)
    }

    // MARK: - Wallet Stats

    /// Get stats for a specific wallet
    func getWalletStats(address: String) async throws -> WalletStatsResponse {
        let result: WalletStatsResponse = try await firebaseClient.call(
            function: "getWalletStats",
            data: ["walletAddress": address]
        )
        return result
    }

    /// Get trades for a specific wallet
    func getWalletTrades(address: String, limit: Int = 20, startAfter: String? = nil) async throws -> GetWalletTradesResponse {
        var data: [String: Any] = [
            "walletAddress": address,
            "limit": limit,
        ]

        if let cursor = startAfter {
            data["startAfter"] = cursor
        }

        let result: GetWalletTradesResponse = try await firebaseClient.call(
            function: "getWalletTrades",
            data: data
        )
        return result
    }
}

// MARK: - Response Types

struct GetTrackedWalletsResponse: Codable {
    let success: Bool
    let wallets: [TrackedWallet]
    let count: Int
}

struct AddTrackedWalletResponse: Codable {
    let success: Bool
    let trackedWallet: TrackedWallet?
}

struct BasicResponse: Codable {
    let success: Bool
    let message: String?
}

struct GetTradeFeedResponse: Codable {
    let success: Bool
    let trades: [TrackedTrade]
    let hasMore: Bool
    let nextCursor: String?
    let degenModeEnabled: Bool?
}

struct WalletStatsResponse: Codable {
    let success: Bool
    let stats: TrackedWallet.WalletStats
}

struct GetWalletTradesResponse: Codable {
    let success: Bool
    let wallet: WalletInfo
    let trades: [TrackedTrade]
    let hasMore: Bool
    let nextCursor: String?

    struct WalletInfo: Codable {
        let address: String
        let nickname: String?
        let stats: TrackedWallet.WalletStats
    }
}

// MARK: - Feed Filter

enum TradeFeedFilter: String, CaseIterable {
    case all
    case buys
    case sells
    case safe
    case degen

    var displayName: String {
        switch self {
        case .all: return "All"
        case .buys: return "Buys"
        case .sells: return "Sells"
        case .safe: return "Safe"
        case .degen: return "Degen"
        }
    }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .buys: return "arrow.down.circle"
        case .sells: return "arrow.up.circle"
        case .safe: return "checkmark.shield"
        case .degen: return "flame"
        }
    }
}

// MARK: - Errors

enum TrackingError: LocalizedError {
    case failedToAdd
    case failedToRemove
    case notFound
    case limitReached

    var errorDescription: String? {
        switch self {
        case .failedToAdd: return "Failed to add wallet"
        case .failedToRemove: return "Failed to remove wallet"
        case .notFound: return "Wallet not found"
        case .limitReached: return "Tracking limit reached. Upgrade to Pro for more."
        }
    }
}
