import Foundation

/// A user's position in a prediction market
struct UserPosition: Identifiable, Codable {
    let id: String
    let userId: String
    let marketAddress: String
    var marketTitle: String?

    // Position details
    let direction: String // "YES" or "NO"
    let amount: Double // USDC cost basis
    let shares: Double
    let avgPrice: Double // Entry price (0-1)

    // Status and P&L
    let status: PositionStatus
    var unrealizedPnl: Double
    var currentPrice: Double? // Current market price (for open positions)
    var currentValue: Double? // Current position value

    // Timestamps
    let createdAt: Date
    var resolvedAt: Date?

    // Source tracking
    var copiedFromWallet: String?
    var copiedFromBetId: String?

    enum PositionStatus: String, Codable {
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

    /// Shortened market address for display
    var shortenedMarketAddress: String {
        guard marketAddress.count >= 8 else { return marketAddress }
        return "\(marketAddress.prefix(4))...\(marketAddress.suffix(4))"
    }

    /// Entry price formatted as cents
    var entryPriceCents: Int {
        Int(avgPrice * 100)
    }

    /// Current price formatted as cents
    var currentPriceCents: Int? {
        guard let price = currentPrice else { return nil }
        return Int(price * 100)
    }

    /// P&L percentage
    var pnlPercentage: Double {
        guard amount > 0 else { return 0 }
        return (unrealizedPnl / amount) * 100
    }

    /// Is this a winning position (for resolved)
    var isWin: Bool {
        status == .won || status == .claimed
    }
}
