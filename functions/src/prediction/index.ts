/**
 * Prediction Markets Module
 *
 * Track whale bets on Jupiter Prediction Markets and copy their positions.
 */

// Predictor tracking
export { addTrackedPredictor } from "./add-tracked-predictor";

// Prediction webhook
export { predictionWebhook } from "./prediction-webhook";

// Admin tools (backfill, data quality, unmapped market review)
export {
  backfillBetConfidence,
  getUnmappedMarketsAdmin,
  getUnverifiedBetsAdmin,
  resolveUnmappedMarket,
  reprocessUnverifiedBets,
  getDataQualityStats,
  monitorDataQuality,
  cleanupOldUnverifiedBets,
} from "./admin-tools";

// Auto-copy execution (notification-based)
export {
  processPredictionCopy,
  markCopyExecuted,
  markCopySkipped,
  cleanupExpiredCopies,
  buildJupiterPredictionUrl,
  type PredictionCopyRequest,
  type PendingCopyTrade,
} from "./execute-prediction-copy";

// Prediction delegation (Privy server-side signing)
export {
  approvePredictionDelegation,
  revokePredictionDelegation,
  type PredictionDelegationConfig,
} from "./approve-prediction-delegation";

// Server-side copy execution
export {
  executePredictionCopyServer,
  autoExecutePredictionCopy,
} from "./execute-prediction-copy-server";

// Market Registry (Jupiter -> Kalshi mapping)
export {
  addMarketMapping,
  discoverMarketMappings,
  syncMarketData,
  getMarketMappings,
  getUnmappedMarkets,
  getMarketMapping,
  getMarketByToken,
  fetchKalshiMarketData,
  type MarketMapping,
} from "./market-registry";

// Bet Resolution (Kalshi-backed)
export {
  resolvePredictionBets,
  triggerBetResolution,
  recalculatePredictorStats,
} from "./resolve-prediction-bets";

// User tracking settings
export {
  updateTrackingSettings,
  getTrackedPredictors,
  removeTrackedPredictor,
  enableAutoCopy,
  disableAutoCopy,
  getCopyTradeHistory,
  type TrackingSettings,
} from "./tracking-settings";

// Smart money discovery (replaces sync-leaderboard)
export {
  discoverProfitableTraders,
  getDiscoveredWallets,
  approveDiscoveredWallet,
  rejectDiscoveredWallet,
  submitWalletSuggestion,
  triggerDiscoveryNow,
} from "./discover-smart-money";

// Historical backfill (replaces backfill-history)
export { backfillWalletBets } from "./backfill-wallet";

// Config and types
export {
  JUPITER_PREDICTION_PROGRAM,
  USDC_MINT,
  PREDICTION_FEES,
  type PredictionBet,
  type TrackedPredictor,
  type PredictorStats,
  type BetDirection,
  type BetStatus,
} from "./prediction-config";
