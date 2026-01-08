/**
 * Prediction Markets Module
 *
 * Track whale bets on Jupiter Prediction Markets and copy their positions.
 */

// Predictor tracking
export { addTrackedPredictor } from "./add-tracked-predictor";

// Prediction webhook
export { predictionWebhook } from "./prediction-webhook";

// Backfill functions
export { backfillWalletHistory } from "./backfill-history";
export { backfillMarketTitles } from "./backfill-market-titles";

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
