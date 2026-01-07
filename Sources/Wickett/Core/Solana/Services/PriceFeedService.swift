import Foundation
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Wickett", category: "PriceFeedService")

/// Service for fetching and caching token prices
@MainActor
class PriceFeedService: ObservableObject {
    static let shared = PriceFeedService()

    @Published var prices: [String: Decimal] = [:]  // symbol → USD price
    @Published var changes24h: [String: Decimal] = [:] // symbol → 24h change %

    private var lastUpdate: Date?
    private let cacheExpiration: TimeInterval = 30 // 30 seconds
    private var refreshTask: Task<Void, Never>?
    
    // CoinGecko ID Mapping - computed from TokenRegistry (single source of truth)
    private var symbolToCoingeckoId: [String: String] {
        Dictionary(uniqueKeysWithValues:
            TokenRegistry.allTokens.compactMap { token in
                token.coingeckoId.map { (token.symbol, $0) }
            }
        )
    }

    // DexScreener tokens - tokens without CoinGecko IDs, computed from TokenRegistry
    private var symbolToMintAddress: [String: String] {
        Dictionary(uniqueKeysWithValues:
            TokenRegistry.allTokens.compactMap { token -> (String, String)? in
                guard token.coingeckoId == nil, let mint = token.mint else { return nil }
                return (token.symbol, mint)
            }
        )
    }

    // All tokens with mint addresses for Birdeye chart data
    private var symbolToMint: [String: String] {
        Dictionary(uniqueKeysWithValues:
            TokenRegistry.allTokens.compactMap { token -> (String, String)? in
                // SOL uses native address, others use mint
                if token.symbol == "SOL" {
                    return ("SOL", "So11111111111111111111111111111111111111112")
                }
                guard let mint = token.mint else { return nil }
                return (token.symbol, mint)
            }
        )
    }

    // Birdeye API key
    private let birdeyeApiKey = "44b8682eb9fa415e913ef198ae2e6e03"

    private init() {}

    // MARK: - Public API

    /// Get current price for a token
    func getPrice(for symbol: String) -> Decimal {
        return prices[symbol] ?? 0
    }

    /// Get 24h change for a token
    func getChange24h(for symbol: String) -> Decimal? {
        return changes24h[symbol]
    }

    /// Refresh prices if cache is expired
    func refreshIfNeeded() async {
        if shouldRefresh() {
            await refreshPrices()
        }
    }

    /// Force refresh prices
    func refreshPrices() async {
        logger.info("🔄 Refreshing token prices...")

        do {
            // Fetch from CoinGecko (main tokens)
            let coingeckoPrices = try await fetchPricesFromCoinGecko()

            // Fetch from DexScreener (xStock tokens not on CoinGecko)
            let dexScreenerPrices = await fetchPricesFromDexScreener()

            await MainActor.run {
                // Merge prices from both sources
                self.prices = coingeckoPrices.prices.merging(dexScreenerPrices.prices) { _, new in new }
                self.changes24h = coingeckoPrices.changes.merging(dexScreenerPrices.changes) { _, new in new }
                self.lastUpdate = Date()
            }

            logger.info("✅ Prices updated: SOL=$\(coingeckoPrices.prices["SOL"] ?? 0), GOLD=$\(dexScreenerPrices.prices["GOLD"] ?? 0)")
        } catch {
            logger.error("❌ Failed to fetch prices: \(error.localizedDescription)")
        }
    }
    
    /// Fetch historical prices for a token using Birdeye OHLCV API
    /// Returns array of [Timestamp: Price]
    func fetchHistoricalPrices(for symbol: String, days: Int = 7) async throws -> [(Date, Decimal)] {
        guard let mintAddress = symbolToMint[symbol] else {
            logger.warning("⚠️ No mint address for \(symbol)")
            return []
        }

        // Calculate time range
        let now = Int(Date().timeIntervalSince1970)
        let timeFrom = now - (days * 24 * 60 * 60)

        // Determine interval based on days
        // 1D = 15m intervals, 1W = 1H intervals, 1M+ = 4H intervals
        let interval: String
        switch days {
        case 1: interval = "15m"
        case 7: interval = "1H"
        case 30: interval = "4H"
        default: interval = "1D"
        }

        // Birdeye OHLCV API
        let urlString = "https://public-api.birdeye.so/defi/ohlcv?address=\(mintAddress)&type=\(interval)&time_from=\(timeFrom)&time_to=\(now)"

        guard let url = URL(string: urlString) else {
            throw PriceFeedError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(birdeyeApiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue("solana", forHTTPHeaderField: "x-chain")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ Invalid response for \(symbol) chart")
            throw PriceFeedError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("❌ Birdeye chart API error: \(httpResponse.statusCode) for \(symbol)")
            throw PriceFeedError.httpError(statusCode: httpResponse.statusCode)
        }

        // Parse Birdeye OHLCV response
        struct BirdeyeResponse: Decodable {
            let success: Bool
            let data: OHLCVData?
        }

        struct OHLCVData: Decodable {
            let items: [OHLCVItem]
        }

        struct OHLCVItem: Decodable {
            let unixTime: Int
            let c: Double  // close price
        }

        let birdeyeResponse = try JSONDecoder().decode(BirdeyeResponse.self, from: data)

        guard birdeyeResponse.success, let items = birdeyeResponse.data?.items else {
            logger.warning("⚠️ No chart data from Birdeye for \(symbol)")
            return []
        }

        logger.info("📈 Birdeye: fetched \(items.count) price points for \(symbol)")

        return items.map { item in
            let timestamp = Date(timeIntervalSince1970: TimeInterval(item.unixTime))
            let price = Decimal(item.c)
            return (timestamp, price)
        }
    }

    /// Start automatic price updates (every 60s)
    func startAutomaticUpdates() {
        stopAutomaticUpdates()

        refreshTask = Task {
            while !Task.isCancelled {
                await refreshPrices()

                // Wait 60 seconds before next update
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }

        logger.info("🔄 Started automatic price updates (60s interval)")
    }

    /// Stop automatic price updates
    func stopAutomaticUpdates() {
        refreshTask?.cancel()
        refreshTask = nil
        logger.info("⏸️ Stopped automatic price updates")
    }

    // MARK: - Private Helpers

    private func shouldRefresh() -> Bool {
        guard let lastUpdate = lastUpdate else { return true }
        return Date().timeIntervalSince(lastUpdate) > cacheExpiration
    }

    /// Fetch prices from DexScreener for xStock tokens
    private func fetchPricesFromDexScreener() async -> (prices: [String: Decimal], changes: [String: Decimal]) {
        var prices: [String: Decimal] = [:]
        var changes: [String: Decimal] = [:]

        // Batch fetch all tokens in one request
        let mintAddresses = symbolToMintAddress.values.joined(separator: ",")
        let urlString = "https://api.dexscreener.com/latest/dex/tokens/\(mintAddresses)"

        guard let url = URL(string: urlString) else {
            logger.warning("⚠️ Invalid DexScreener URL")
            return (prices, changes)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.warning("⚠️ DexScreener returned non-200 status")
                return (prices, changes)
            }

            // Parse DexScreener response
            struct DexScreenerResponse: Decodable {
                let pairs: [DexPair]?
            }

            struct DexPair: Decodable {
                let baseToken: BaseToken
                let priceUsd: String?
                let priceChange: PriceChange?
            }

            struct BaseToken: Decodable {
                let address: String
                let symbol: String
            }

            struct PriceChange: Decodable {
                let h24: Double?
            }

            let dexResponse = try JSONDecoder().decode(DexScreenerResponse.self, from: data)

            // Map addresses back to symbols and extract prices
            let addressToSymbol = Dictionary(uniqueKeysWithValues: symbolToMintAddress.map { ($1, $0) })

            for pair in dexResponse.pairs ?? [] {
                let address = pair.baseToken.address
                if let symbol = addressToSymbol[address],
                   let priceString = pair.priceUsd,
                   let priceDouble = Double(priceString) {
                    // Only use the first (highest liquidity) pair for each token
                    if prices[symbol] == nil {
                        prices[symbol] = Decimal(priceDouble)
                        if let change24h = pair.priceChange?.h24 {
                            changes[symbol] = Decimal(change24h)
                        }
                        logger.info("   \(symbol): $\(priceDouble)")
                    }
                }
            }

            logger.info("✅ DexScreener: fetched \(prices.count) xStock prices")
        } catch {
            logger.warning("⚠️ DexScreener fetch failed: \(error.localizedDescription)")
        }

        return (prices, changes)
    }

    private func fetchPricesFromCoinGecko() async throws -> (prices: [String: Decimal], changes: [String: Decimal]) {
        // CoinGecko API endpoint (free tier)
        let coingeckoIds = symbolToCoingeckoId.values.joined(separator: ",")

        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=\(coingeckoIds)&vs_currencies=usd&include_24hr_change=true"

        guard let url = URL(string: urlString) else {
            throw PriceFeedError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PriceFeedError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw PriceFeedError.httpError(statusCode: httpResponse.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]]

        guard let json = json else {
            throw PriceFeedError.invalidData
        }

        var prices: [String: Decimal] = [:]
        var changes: [String: Decimal] = [:]

        // Map back from CoinGecko ID to Symbol
        for (symbol, id) in symbolToCoingeckoId {
            if let coinData = json[id] {
                prices[symbol] = coinData["usd"].map { Decimal($0) } ?? 0
                changes[symbol] = coinData["usd_24h_change"].map { Decimal($0) }
            }
        }

        return (prices, changes)
    }
}

// MARK: - Errors

enum PriceFeedError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid price feed URL"
        case .invalidResponse:
            return "Invalid response from price feed"
        case .httpError(let statusCode):
            return "Price feed error: HTTP \(statusCode)"
        case .invalidData:
            return "Invalid price data format"
        }
    }
}
