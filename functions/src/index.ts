import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// ============================================
// AUTH & USER (6 functions)
// ============================================

export { createFirebaseCustomToken } from "./privy-firebase-bridge";
export { createServerWallet } from "./users/create-server-wallet";
export { updateWalletAddress } from "./users/update-wallet-address";
export { checkUsernameAvailability } from "./users/check-username-availability";
export { updateUsername } from "./users/update-username";
export { deleteUserAccount } from "./users/delete-user-account";

// ============================================
// PREDICTION MARKETS (5 functions)
// ============================================

// Webhook - receives Helius transactions for smart money bets
export { predictionWebhook } from "./prediction/prediction-webhook";

// Resolution - checks market outcomes hourly
export { resolvePredictionBets } from "./prediction/resolve-prediction-bets";

// Smart money wallets - curated list
export {
  getSmartMoneyWallets,
  addSmartMoneyWallet,
  removeSmartMoneyWallet,
} from "./prediction/smart-money-wallets";

// ============================================
// COPY TRADING (6 functions)
// ============================================

// Delegation - enable/disable server-side execution
export {
  approvePredictionDelegation,
  revokePredictionDelegation,
} from "./prediction/approve-prediction-delegation";

// Server-side copy execution
export { executePredictionCopyServer } from "./prediction/execute-prediction-copy-server";

// Auto-execute trigger (Firestore onCreate)
export { onPendingCopyCreated } from "./prediction/auto-execute-copy";

// User tracking settings
export {
  updateTrackingSettings,
  getTrackedPredictors,
  enableAutoCopy,
  disableAutoCopy,
} from "./prediction/tracking-settings";

// ============================================
// MARKET REGISTRY (2 functions)
// ============================================

// Map Jupiter markets to Kalshi for resolution
export {
  addMarketMapping,
  getUnmappedMarkets,
} from "./prediction/market-registry";

// Smart money discovery (fully automated)
export {
  // On-chain scanner (finds NEW traders from blockchain)
  scanProgramForTraders,
  triggerOnChainScan,
  // Internal data discovery
  discoverProfitableTraders,
  triggerDiscoveryNow,
  // Community suggestions (still available)
  getDiscoveredWallets,
  approveDiscoveredWallet,
  rejectDiscoveredWallet,
  submitWalletSuggestion,
} from "./prediction/discover-smart-money";

// ============================================
// HOT MARKET DETECTION (3 functions)
// ============================================

// Detect when multiple smart bettors bet same direction
export {
  detectHotMarkets,
  getHotMarkets,
  triggerHotMarketDetection,
} from "./prediction/hot-market-detection";
