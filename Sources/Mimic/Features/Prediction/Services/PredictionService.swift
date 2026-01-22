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
    @Published var hotMarkets: [HotMarket] = []
    @Published var isLoadingWallets = false
    @Published var isLoadingFeed = false
    @Published var isLoadingHotMarkets = false
    @Published var errorMessage: String?

    private var lastBetDocument: DocumentSnapshot?
    private var hasMoreFeed = true
    private var feedListener: ListenerRegistration?
    private var hotMarketsListener: ListenerRegistration?

    private init() {}

    deinit {
        feedListener?.remove()
        hotMarketsListener?.remove()
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
            // Query prediction bets (validation happens at webhook level)
            var query: Query = db.collection("prediction_bets")
                .order(by: "timestamp", descending: true)
                .limit(to: 20)

            // Apply status filters at query level (more efficient)
            switch filter {
            case .open:
                query = query.whereField("status", isEqualTo: "open")
            case .resolved:
                query = query.whereField("status", in: ["won", "lost", "claimed"])
            default:
                break
            }

            // Pagination
            if let lastDoc = lastBetDocument {
                query = query.start(afterDocument: lastDoc)
            }

            let snapshot = try await query.getDocuments()

            var newBets = snapshot.documents.compactMap { doc in
                parsePredictionBet(doc)
            }.filter { bet in
                // Filter out invalid bets (must have amount > 0)
                bet.amount > 0
            }

            // Apply category filter client-side
            if let categoryMatches = filter.categoryMatches {
                newBets = newBets.filter { bet in
                    // Check category field first
                    if let category = bet.marketCategory?.lowercased() {
                        if categoryMatches.contains(where: { category.contains($0.lowercased()) }) {
                            return true
                        }
                    }
                    // Fallback: check market title for keywords
                    if let title = bet.marketTitle?.lowercased() {
                        return categoryMatches.contains { title.contains($0.lowercased()) }
                    }
                    return false
                }
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
                    }.filter { bet in
                        // Filter out invalid bets (must have amount > 0)
                        bet.amount > 0
                    }
                }
            }
    }

    func stopFeedListener() {
        feedListener?.remove()
        feedListener = nil
    }

    // MARK: - Hot Markets (Trending)

    /// Load hot markets where multiple smart bettors are converging
    func loadHotMarkets() async {
        guard !isLoadingHotMarkets else { return }

        isLoadingHotMarkets = true

        do {
            let snapshot = try await db.collection("hot_markets")
                .whereField("isActive", isEqualTo: true)
                .order(by: "totalBettors", descending: true)
                .limit(to: 20)
                .getDocuments()

            hotMarkets = snapshot.documents.compactMap { doc in
                parseHotMarket(doc)
            }

            logger.info("Loaded \(self.hotMarkets.count) hot markets")
        } catch {
            logger.error("Failed to load hot markets: \(error.localizedDescription)")
        }

        isLoadingHotMarkets = false
    }

    /// Start real-time listener for hot markets
    func startHotMarketsListener() {
        hotMarketsListener?.remove()

        hotMarketsListener = db.collection("hot_markets")
            .whereField("isActive", isEqualTo: true)
            .order(by: "totalBettors", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.logger.error("Hot markets listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    self.hotMarkets = documents.compactMap { doc in
                        self.parseHotMarket(doc)
                    }
                }
            }
    }

    func stopHotMarketsListener() {
        hotMarketsListener?.remove()
        hotMarketsListener = nil
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
        // Check both 'direction' and 'position' for backwards compatibility
        if let dirStr = data["direction"] as? String {
            direction = PredictionBet.BetDirection(rawValue: dirStr) ?? .yes
        } else if let posStr = data["position"] as? String {
            direction = PredictionBet.BetDirection(rawValue: posStr) ?? .yes
        } else {
            direction = .yes
        }

        let status: PredictionBet.BetStatus
        if let statusStr = data["status"] as? String {
            // Map "pending" to "open" for backwards compatibility
            let normalizedStatus = statusStr == "pending" ? "open" : statusStr
            status = PredictionBet.BetStatus(rawValue: normalizedStatus) ?? .open
        } else {
            status = .open
        }

        // Parse numeric fields (handle both Int and Double from Firestore)
        let amount: Double
        if let d = data["amount"] as? Double {
            amount = d
        } else if let i = data["amount"] as? Int {
            amount = Double(i)
        } else if let n = data["amount"] as? NSNumber {
            amount = n.doubleValue
        } else {
            amount = 0
        }

        let shares: Double
        if let d = data["shares"] as? Double {
            shares = d
        } else if let i = data["shares"] as? Int {
            shares = Double(i)
        } else if let n = data["shares"] as? NSNumber {
            shares = n.doubleValue
        } else {
            shares = 0
        }

        let avgPrice: Double
        if let d = data["avgPrice"] as? Double {
            avgPrice = d
        } else if let i = data["avgPrice"] as? Int {
            avgPrice = Double(i)
        } else if let n = data["avgPrice"] as? NSNumber {
            avgPrice = n.doubleValue
        } else {
            avgPrice = 0
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
            amount: amount,
            shares: shares,
            avgPrice: avgPrice,
            status: status,
            pnl: data["pnl"] as? Double,
            canCopy: data["canCopy"] as? Bool ?? true
        )
    }

    private func parseHotMarket(_ doc: DocumentSnapshot) -> HotMarket? {
        let data = doc.data() ?? [:]

        guard let marketAddress = data["marketAddress"] as? String else {
            return nil
        }

        let firstBetAt: Date?
        if let ts = data["firstBetAt"] as? Timestamp {
            firstBetAt = ts.dateValue()
        } else {
            firstBetAt = nil
        }

        let lastBetAt: Date?
        if let ts = data["lastBetAt"] as? Timestamp {
            lastBetAt = ts.dateValue()
        } else {
            lastBetAt = nil
        }

        let detectedAt: Date?
        if let ts = data["detectedAt"] as? Timestamp {
            detectedAt = ts.dateValue()
        } else {
            detectedAt = nil
        }

        return HotMarket(
            id: doc.documentID,
            marketAddress: marketAddress,
            marketTitle: data["marketTitle"] as? String,
            category: data["category"] as? String,
            kalshiTicker: data["kalshiTicker"] as? String,
            totalBettors: data["totalBettors"] as? Int ?? 0,
            yesBettors: data["yesBettors"] as? Int ?? 0,
            noBettors: data["noBettors"] as? Int ?? 0,
            consensusDirection: data["consensusDirection"] as? String ?? "SPLIT",
            consensusPercentage: data["consensusPercentage"] as? Double ?? 0,
            totalVolume: data["totalVolume"] as? Double ?? 0,
            yesVolume: data["yesVolume"] as? Double ?? 0,
            noVolume: data["noVolume"] as? Double ?? 0,
            firstBetAt: firstBetAt,
            lastBetAt: lastBetAt,
            detectedAt: detectedAt,
            isActive: data["isActive"] as? Bool ?? true,
            heatLevel: data["heatLevel"] as? String ?? "warm"
        )
    }
}

// MARK: - Feed Filter

enum BetFeedFilter: String, CaseIterable {
    case all
    case trending
    case sports
    case crypto
    case politics
    case economics
    case open
    case resolved

    var displayName: String {
        switch self {
        case .all: return "All"
        case .trending: return "Trending"
        case .sports: return "Sports"
        case .crypto: return "Crypto"
        case .politics: return "Politics"
        case .economics: return "Economics"
        case .open: return "Open"
        case .resolved: return "Resolved"
        }
    }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .trending: return "flame.fill"
        case .sports: return "sportscourt"
        case .crypto: return "bitcoinsign.circle"
        case .politics: return "building.columns"
        case .economics: return "chart.line.uptrend.xyaxis"
        case .open: return "clock"
        case .resolved: return "flag.checkered"
        }
    }

    /// Whether this filter shows hot markets instead of bets
    var showsHotMarkets: Bool {
        self == .trending
    }

    /// Keywords to match category or title
    var categoryMatches: [String]? {
        switch self {
        case .sports: return ["sports", "nfl", "nba", "mlb", "nhl", "soccer", "football", "basketball", "baseball", "hockey", "championship", "playoff", "super bowl"]
        case .crypto: return ["crypto", "bitcoin", "btc", "ethereum", "eth", "solana", "sol", "$150k", "$100k", "$200k"]
        case .politics: return ["politics", "election", "trump", "biden", "president", "congress", "senate", "governor"]
        case .economics: return ["economics", "finance", "fed", "rate", "inflation", "gdp", "recession", "unemployment", "interest rate"]
        default: return nil
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
