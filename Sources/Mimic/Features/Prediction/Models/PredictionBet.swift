import Foundation

/// A prediction market bet from a tracked predictor
struct PredictionBet: Identifiable, Codable {
    let id: String
    let walletAddress: String
    var walletNickname: String?
    let signature: String
    let timestamp: Date

    // Market info
    let marketAddress: String
    var marketTitle: String?
    var marketCategory: String?

    // Bet details
    let direction: BetDirection
    let amount: Double // USDC amount
    let shares: Double
    let avgPrice: Double

    // Status
    let status: BetStatus
    var pnl: Double?

    // Tracking
    let canCopy: Bool

    enum BetDirection: String, Codable {
        case yes = "YES"
        case no = "NO"

        var displayName: String {
            switch self {
            case .yes: return "YES"
            case .no: return "NO"
            }
        }

        var color: String {
            switch self {
            case .yes: return "green"
            case .no: return "red"
            }
        }
    }

    enum BetStatus: String, Codable {
        case open
        case won
        case lost
        case claimed

        var displayName: String {
            switch self {
            case .open: return "Open"
            case .won: return "Won"
            case .lost: return "Lost"
            case .claimed: return "Claimed"
            }
        }
    }

    /// Display name for the wallet
    var displayName: String {
        walletNickname ?? shortenedAddress
    }

    /// Shortened wallet address for display
    var shortenedAddress: String {
        guard walletAddress.count >= 8 else { return walletAddress }
        return "\(walletAddress.prefix(4))...\(walletAddress.suffix(4))"
    }

    /// Bet description for display
    var betDescription: String {
        "\(direction.displayName) @ \(String(format: "%.0f", avgPrice * 100))¢"
    }

    /// Formatted amount
    var formattedAmount: String {
        "$\(String(format: "%.0f", amount))"
    }

    /// Explorer URL for the transaction
    var explorerURL: URL? {
        URL(string: "https://solscan.io/tx/\(signature)")
    }
}

/// A predictor wallet being tracked
struct TrackedPredictor: Identifiable, Codable {
    let id: String
    let userId: String
    let walletAddress: String
    var nickname: String?
    let createdAt: Date
    var stats: PredictorStats?

    // Copy trading settings
    var autoCopyEnabled: Bool
    var copyPercentage: Double       // % of original bet to copy (e.g., 5 = 5%)
    var maxCopyAmountUsd: Double     // Max USD per copy bet
    var minBetSizeUsd: Double        // Min original bet size to trigger copy

    init(
        id: String,
        userId: String,
        walletAddress: String,
        nickname: String? = nil,
        createdAt: Date = Date(),
        stats: PredictorStats? = nil,
        autoCopyEnabled: Bool = false,
        copyPercentage: Double = 5,
        maxCopyAmountUsd: Double = 50,
        minBetSizeUsd: Double = 5
    ) {
        self.id = id
        self.userId = userId
        self.walletAddress = walletAddress
        self.nickname = nickname
        self.createdAt = createdAt
        self.stats = stats
        self.autoCopyEnabled = autoCopyEnabled
        self.copyPercentage = copyPercentage
        self.maxCopyAmountUsd = maxCopyAmountUsd
        self.minBetSizeUsd = minBetSizeUsd
    }

    /// Display name for the predictor
    var displayName: String {
        nickname ?? shortenedAddress
    }

    /// Shortened wallet address for display
    var shortenedAddress: String {
        guard walletAddress.count >= 8 else { return walletAddress }
        return "\(walletAddress.prefix(4))...\(walletAddress.suffix(4))"
    }
}

/// Predictor statistics
struct PredictorStats: Codable {
    var totalBets: Int
    var winRate: Double
    var totalPnl: Double
    var avgBetSize: Double
    var lastBetAt: Date?

    /// Formatted win rate
    var formattedWinRate: String {
        "\(Int(winRate * 100))%"
    }

    /// Formatted P&L
    var formattedPnl: String {
        let prefix = totalPnl >= 0 ? "+" : ""
        return "\(prefix)$\(String(format: "%.0f", totalPnl))"
    }
}
