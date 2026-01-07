import Foundation

/// A trade from a tracked wallet
struct TrackedTrade: Identifiable, Codable {
    let id: String
    let walletAddress: String
    var walletNickname: String?
    let signature: String
    let timestamp: Date
    let type: TradeType
    let inputToken: TokenInfo
    let outputToken: TokenInfo
    let isSafeModeTrade: Bool
    var canCopy: Bool = true

    enum TradeType: String, Codable {
        case buy
        case sell
    }

    struct TokenInfo: Codable {
        let mint: String
        let symbol: String
        let amount: Double
        var usdValue: Double?
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

    /// Trade description for display
    var tradeDescription: String {
        "\(inputToken.symbol) → \(outputToken.symbol)"
    }

    /// Explorer URL for the transaction
    var explorerURL: URL? {
        URL(string: "https://solscan.io/tx/\(signature)")
    }
}

/// A wallet being tracked
struct TrackedWallet: Identifiable, Codable {
    let id: String
    let userId: String
    let walletAddress: String
    var nickname: String?
    let createdAt: Date
    var stats: WalletStats

    struct WalletStats: Codable {
        var totalTrades: Int
        var winRate: Double
        var pnl: Double
        var lastTradeAt: Date?
    }

    /// Display name for the wallet
    var displayName: String {
        nickname ?? shortenedAddress
    }

    /// Shortened wallet address for display
    var shortenedAddress: String {
        guard walletAddress.count >= 8 else { return walletAddress }
        return "\(walletAddress.prefix(4))...\(walletAddress.suffix(4))"
    }
}
