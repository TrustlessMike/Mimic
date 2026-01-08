import Foundation
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "JupiterPredictionAPI")

/// Client for Jupiter Prediction Markets API
/// Fetches smart money signals directly from Jupiter
@MainActor
class JupiterPredictionAPI: ObservableObject {
    static let shared = JupiterPredictionAPI()

    private let baseURL = "https://prediction-market-api.jup.ag/api/v1"
    private let session: URLSession
    private let decoder: JSONDecoder

    @Published var topTraders: [JupiterTrader] = []
    @Published var smartMoneyPositions: [JupiterPosition] = []
    @Published var isLoading = false
    @Published var error: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Leaderboard

    /// Fetch top traders from Jupiter Prediction Markets
    func fetchLeaderboard(
        period: LeaderboardPeriod = .allTime,
        metric: LeaderboardMetric = .pnl,
        limit: Int = 50
    ) async throws -> [JupiterTrader] {
        let url = URL(string: "\(baseURL)/leaderboards")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "period", value: period.rawValue),
            URLQueryItem(name: "metric", value: metric.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        let (data, _) = try await session.data(from: components.url!)
        let response = try decoder.decode(LeaderboardResponse.self, from: data)

        topTraders = response.data
        logger.info("Fetched \(response.data.count) traders from leaderboard")
        return response.data
    }

    /// Fetch positions for a specific wallet
    func fetchPositions(wallet: String) async throws -> [JupiterPosition] {
        var components = URLComponents(string: "\(baseURL)/positions")!
        components.queryItems = [
            URLQueryItem(name: "ownerPubkey", value: wallet)
        ]

        let (data, _) = try await session.data(from: components.url!)
        let response = try decoder.decode(PositionsResponse.self, from: data)
        return response.data
    }

    // MARK: - Smart Money Feed

    /// Fetch all open positions from top traders (smart money signals)
    func fetchSmartMoneySignals(topN: Int = 30) async {
        isLoading = true
        error = nil

        do {
            // Get top traders
            let traders = try await fetchLeaderboard(limit: topN)

            // Fetch positions for each trader
            var allPositions: [JupiterPosition] = []

            for trader in traders {
                do {
                    let positions = try await fetchPositions(wallet: trader.ownerPubkey)
                    allPositions.append(contentsOf: positions)

                    // Rate limiting
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                } catch {
                    logger.warning("Failed to fetch positions for \(trader.ownerPubkey.prefix(8)): \(error.localizedDescription)")
                }
            }

            // Sort by size (biggest bets first)
            smartMoneyPositions = allPositions.sorted { $0.sizeUsdDouble > $1.sizeUsdDouble }

            logger.info("Fetched \(allPositions.count) smart money positions")
        } catch {
            self.error = error.localizedDescription
            logger.error("Failed to fetch smart money signals: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Get aggregated signals by market
    func getAggregatedSignals() -> [AggregatedSignal] {
        var signals: [String: AggregatedSignal] = [:]

        for position in smartMoneyPositions {
            let key = position.marketId

            if var existing = signals[key] {
                existing.traderCount += 1
                if position.isYes {
                    existing.yesSizeUsd += position.sizeUsdDouble
                } else {
                    existing.noSizeUsd += position.sizeUsdDouble
                }
                existing.totalSizeUsd += position.sizeUsdDouble
                signals[key] = existing
            } else {
                signals[key] = AggregatedSignal(
                    marketId: position.marketId,
                    eventTitle: position.eventMetadata.title,
                    marketTitle: position.marketMetadata.title,
                    category: position.eventMetadata.category,
                    traderCount: 1,
                    yesSizeUsd: position.isYes ? position.sizeUsdDouble : 0,
                    noSizeUsd: position.isYes ? 0 : position.sizeUsdDouble,
                    totalSizeUsd: position.sizeUsdDouble,
                    currentPrice: position.markPriceDouble,
                    settlementDate: Date(timeIntervalSince1970: TimeInterval(position.settlementDate))
                )
            }
        }

        return signals.values.sorted { $0.totalSizeUsd > $1.totalSizeUsd }
    }
}

// MARK: - Enums

enum LeaderboardPeriod: String {
    case allTime = "all_time"
    case weekly = "weekly"
    case monthly = "monthly"
}

enum LeaderboardMetric: String {
    case pnl = "pnl"
    case volume = "volume"
    case winRate = "win_rate"
}

// MARK: - Response Models

struct LeaderboardResponse: Codable {
    let data: [JupiterTrader]
    let summary: LeaderboardSummary?
}

struct LeaderboardSummary: Codable {
    let all_time: PeriodSummary?
    let weekly: PeriodSummary?
    let monthly: PeriodSummary?
}

struct PeriodSummary: Codable {
    let totalVolumeUsd: String
    let predictionsCount: Int
}

struct JupiterTrader: Codable, Identifiable {
    let ownerPubkey: String
    let realizedPnlUsd: String
    let totalVolumeUsd: String
    let predictionsCount: Int
    let correctPredictions: Int
    let wrongPredictions: Int
    let winRatePct: String
    let period: String

    var id: String { ownerPubkey }

    var pnlUsd: Double {
        (Double(realizedPnlUsd) ?? 0) / 1_000_000
    }

    var volumeUsd: Double {
        (Double(totalVolumeUsd) ?? 0) / 1_000_000
    }

    var winRate: Double {
        (Double(winRatePct) ?? 0) / 100
    }

    var shortAddress: String {
        "\(ownerPubkey.prefix(4))...\(ownerPubkey.suffix(4))"
    }
}

struct PositionsResponse: Codable {
    let data: [JupiterPosition]
    let pagination: Pagination
}

struct Pagination: Codable {
    let start: Int
    let end: Int
    let total: Int
    let hasNext: Bool
}

struct JupiterPosition: Codable, Identifiable {
    let pubkey: String
    let owner: String
    let market: String
    let marketId: String
    let isYes: Bool
    let contracts: String
    let sizeUsd: String
    let avgPriceUsd: String
    let markPriceUsd: String
    let pnlUsd: String
    let eventId: String
    let settlementDate: Int
    let eventMetadata: EventMetadata
    let marketMetadata: MarketMetadata

    var id: String { pubkey }

    var sizeUsdDouble: Double {
        (Double(sizeUsd) ?? 0) / 1_000_000
    }

    var avgPriceDouble: Double {
        (Double(avgPriceUsd) ?? 0) / 1_000_000
    }

    var markPriceDouble: Double {
        (Double(markPriceUsd) ?? 0) / 1_000_000
    }

    var pnlUsdDouble: Double {
        (Double(pnlUsd) ?? 0) / 1_000_000
    }

    var contractsInt: Int {
        Int(contracts) ?? 0
    }
}

struct EventMetadata: Codable {
    let eventId: String
    let title: String
    let subtitle: String
    let isActive: Bool
    let category: String
    let imageUrl: String?
    let isLive: Bool
}

struct MarketMetadata: Codable {
    let marketId: String
    let eventId: String
    let title: String
    let status: String
    let isTradable: Bool
}

// MARK: - Aggregated Signal

struct AggregatedSignal: Identifiable {
    let marketId: String
    let eventTitle: String
    let marketTitle: String
    let category: String
    var traderCount: Int
    var yesSizeUsd: Double
    var noSizeUsd: Double
    var totalSizeUsd: Double
    let currentPrice: Double
    let settlementDate: Date

    var id: String { marketId }

    var dominantSide: String {
        yesSizeUsd > noSizeUsd ? "YES" : "NO"
    }

    var confidence: Double {
        let dominant = max(yesSizeUsd, noSizeUsd)
        guard totalSizeUsd > 0 else { return 0 }
        return dominant / totalSizeUsd
    }

    var formattedSize: String {
        "$\(String(format: "%.0f", totalSizeUsd))"
    }

    var formattedPrice: String {
        "\(String(format: "%.1f", currentPrice * 100))¢"
    }
}
