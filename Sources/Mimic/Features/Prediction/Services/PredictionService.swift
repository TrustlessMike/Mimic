import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog

/// Smart Money Wallet - curated list of sharp bettors
struct SmartMoneyWallet: Identifiable {
    let id: String
    let address: String
    let nickname: String?
    let notes: String?
    let stats: PredictorStats
    let addedAt: Date
    let isActive: Bool
}

/// Service for prediction market tracking
/// Shows a global feed of bets from curated smart money wallets
/// No user tracking required - everyone sees the same smart money feed
@MainActor
class PredictionService: ObservableObject {
    static let shared = PredictionService()

    private let logger = Logger(subsystem: "com.mimic.app", category: "PredictionService")
    private let db = Firestore.firestore()

    @Published var smartMoneyWallets: [SmartMoneyWallet] = []
    @Published var betFeed: [PredictionBet] = []
    @Published var isLoadingWallets = false
    @Published var isLoadingFeed = false
    @Published var errorMessage: String?

    private var lastBetDocument: DocumentSnapshot?
    private var hasMoreFeed = true
    private var feedListener: ListenerRegistration?

    private init() {}

    deinit {
        feedListener?.remove()
    }

    // MARK: - Smart Money Wallets (Curated List)

    /// Load the curated smart money wallets
    func loadSmartMoneyWallets() async {
        guard !isLoadingWallets else { return }

        isLoadingWallets = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("smart_money_wallets")
                .whereField("isActive", isEqualTo: true)
                .order(by: "stats.winRate", descending: true)
                .getDocuments()

            smartMoneyWallets = snapshot.documents.compactMap { doc in
                parseSmartMoneyWallet(doc)
            }

            logger.info("Loaded \(self.smartMoneyWallets.count) smart money wallets")
        } catch {
            logger.error("Failed to load smart money wallets: \(error.localizedDescription)")
            errorMessage = "Failed to load smart money wallets"
        }

        isLoadingWallets = false
    }

    // MARK: - Global Bet Feed

    /// Load the global bet feed from all smart money wallets
    func loadBetFeed(filter: BetFeedFilter = .all, refresh: Bool = false) async {
        guard !isLoadingFeed else { return }

        if refresh {
            lastBetDocument = nil
            hasMoreFeed = true
            betFeed = []
        }

        guard hasMoreFeed else { return }

        isLoadingFeed = true
        errorMessage = nil

        do {
            // Query ALL prediction bets (they're all from smart money wallets)
            var query: Query = db.collection("prediction_bets")
                .order(by: "timestamp", descending: true)
                .limit(to: 20)

            // Apply filter
            switch filter {
            case .yes:
                query = query.whereField("direction", isEqualTo: "YES")
            case .no:
                query = query.whereField("direction", isEqualTo: "NO")
            case .open:
                query = query.whereField("status", isEqualTo: "open")
            case .resolved:
                query = query.whereField("status", in: ["won", "lost", "claimed"])
            case .all:
                break
            }

            // Pagination
            if let lastDoc = lastBetDocument {
                query = query.start(afterDocument: lastDoc)
            }

            let snapshot = try await query.getDocuments()

            let newBets = snapshot.documents.compactMap { doc in
                parsePredictionBet(doc)
            }

            if refresh {
                betFeed = newBets
            } else {
                betFeed.append(contentsOf: newBets)
            }

            lastBetDocument = snapshot.documents.last
            hasMoreFeed = snapshot.documents.count == 20

            logger.info("Loaded \(newBets.count) bets, hasMore: \(self.hasMoreFeed)")
        } catch {
            logger.error("Failed to load bet feed: \(error.localizedDescription)")
            errorMessage = "Failed to load bet feed"
        }

        isLoadingFeed = false
    }

    /// Load more bets (pagination)
    func loadMoreBets(filter: BetFeedFilter = .all) async {
        await loadBetFeed(filter: filter, refresh: false)
    }

    /// Refresh bet feed
    func refreshFeed(filter: BetFeedFilter = .all) async {
        await loadBetFeed(filter: filter, refresh: true)
    }

    /// Start real-time listener for bet feed
    func startFeedListener() {
        feedListener?.remove()

        feedListener = db.collection("prediction_bets")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.logger.error("Feed listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    self.betFeed = documents.compactMap { doc in
                        self.parsePredictionBet(doc)
                    }
                }
            }
    }

    func stopFeedListener() {
        feedListener?.remove()
        feedListener = nil
    }

    // MARK: - Wallet Stats

    /// Get stats for a specific smart money wallet
    func getWalletStats(address: String) async throws -> PredictorStats {
        let snapshot = try await db.collection("smart_money_wallets")
            .whereField("address", isEqualTo: address)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw PredictionError.notFound
        }

        let data = doc.data()
        return parsePredictorStats(data["stats"] as? [String: Any] ?? [:])
    }

    /// Get bets for a specific wallet
    func getWalletBets(
        address: String,
        limit: Int = 20,
        lastDocument: DocumentSnapshot? = nil
    ) async throws -> (bets: [PredictionBet], lastDoc: DocumentSnapshot?, hasMore: Bool) {
        var query: Query = db.collection("prediction_bets")
            .whereField("walletAddress", isEqualTo: address)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)

        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }

        let snapshot = try await query.getDocuments()

        let bets = snapshot.documents.compactMap { doc in
            parsePredictionBet(doc)
        }

        return (
            bets: bets,
            lastDoc: snapshot.documents.last,
            hasMore: snapshot.documents.count == limit
        )
    }

    // MARK: - Parsing Helpers

    private func parseSmartMoneyWallet(_ doc: DocumentSnapshot) -> SmartMoneyWallet? {
        let data = doc.data() ?? [:]

        guard let address = data["address"] as? String else {
            return nil
        }

        let addedAt: Date
        if let timestamp = data["addedAt"] as? Timestamp {
            addedAt = timestamp.dateValue()
        } else {
            addedAt = Date()
        }

        let stats = parsePredictorStats(data["stats"] as? [String: Any] ?? [:])

        return SmartMoneyWallet(
            id: doc.documentID,
            address: address,
            nickname: data["nickname"] as? String,
            notes: data["notes"] as? String,
            stats: stats,
            addedAt: addedAt,
            isActive: data["isActive"] as? Bool ?? true
        )
    }

    private func parsePredictorStats(_ data: [String: Any]) -> PredictorStats {
        var lastBetAt: Date?
        if let timestamp = data["lastBetAt"] as? Timestamp {
            lastBetAt = timestamp.dateValue()
        }

        return PredictorStats(
            totalBets: data["totalBets"] as? Int ?? 0,
            winRate: data["winRate"] as? Double ?? 0,
            totalPnl: data["totalPnl"] as? Double ?? 0,
            avgBetSize: data["avgBetSize"] as? Double ?? 0,
            lastBetAt: lastBetAt
        )
    }

    private func parsePredictionBet(_ doc: DocumentSnapshot) -> PredictionBet? {
        let data = doc.data() ?? [:]

        guard let walletAddress = data["walletAddress"] as? String,
              let signature = data["signature"] as? String,
              let marketAddress = data["marketAddress"] as? String else {
            return nil
        }

        let timestamp: Date
        if let ts = data["timestamp"] as? Timestamp {
            timestamp = ts.dateValue()
        } else if let tsNumber = data["timestamp"] as? TimeInterval {
            timestamp = Date(timeIntervalSince1970: tsNumber)
        } else {
            timestamp = Date()
        }

        let direction: PredictionBet.BetDirection
        if let dirStr = data["direction"] as? String {
            direction = PredictionBet.BetDirection(rawValue: dirStr) ?? .yes
        } else {
            direction = .yes
        }

        let status: PredictionBet.BetStatus
        if let statusStr = data["status"] as? String {
            status = PredictionBet.BetStatus(rawValue: statusStr) ?? .open
        } else {
            status = .open
        }

        return PredictionBet(
            id: doc.documentID,
            walletAddress: walletAddress,
            walletNickname: data["walletNickname"] as? String,
            signature: signature,
            timestamp: timestamp,
            marketAddress: marketAddress,
            marketTitle: data["marketTitle"] as? String,
            marketCategory: data["marketCategory"] as? String,
            direction: direction,
            amount: data["amount"] as? Double ?? 0,
            shares: data["shares"] as? Double ?? 0,
            avgPrice: data["avgPrice"] as? Double ?? 0,
            status: status,
            pnl: data["pnl"] as? Double,
            canCopy: data["canCopy"] as? Bool ?? true
        )
    }
}

// MARK: - Feed Filter

enum BetFeedFilter: String, CaseIterable {
    case all
    case yes
    case no
    case open
    case resolved

    var displayName: String {
        switch self {
        case .all: return "All"
        case .yes: return "YES"
        case .no: return "NO"
        case .open: return "Open"
        case .resolved: return "Resolved"
        }
    }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .yes: return "checkmark.circle"
        case .no: return "xmark.circle"
        case .open: return "clock"
        case .resolved: return "flag.checkered"
        }
    }
}

// MARK: - Errors

enum PredictionError: LocalizedError {
    case notFound
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .notFound: return "Wallet not found"
        case .loadFailed: return "Failed to load data"
        }
    }
}
