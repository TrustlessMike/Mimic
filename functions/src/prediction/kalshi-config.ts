/**
 * Kalshi configuration and constants
 * Jupiter Prediction uses Kalshi as its data source - markets can be matched by event_ticker
 */

// Kalshi API endpoints (no auth needed for public market data)
export const KALSHI_API = "https://api.elections.kalshi.com/trade-api/v2";

// Alternative endpoints
export const KALSHI_TRADING_API = "https://trading-api.kalshi.com/trade-api/v2";
export const KALSHI_DEMO_API = "https://demo-api.kalshi.co/trade-api/v2";

// Market categories on Kalshi
export const KALSHI_CATEGORIES = [
  "Politics",
  "Economics",
  "Companies",
  "World",
  "Science",
  "Sports",
  "Entertainment",
  "Crypto",
];

// Signal thresholds
export const KALSHI_SIGNAL_THRESHOLDS = {
  minVolume: 1000,           // $1000 minimum volume
  minOddsChange: 0.03,       // 3% odds change to trigger signal
  minLiquidity: 500,         // $500 minimum liquidity
  maxSpread: 0.10,           // 10% max bid-ask spread
};

// Jupiter uses Kalshi event tickers - prefix mapping
// Jupiter eventId like "KXSB-26" maps directly to Kalshi event_ticker
export const JUPITER_KALSHI_PREFIX = "KX";
