import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// ============================================
// ESSENTIAL FUNCTIONS (8 total)
// ============================================

// Auth - Privy bridge
export { createFirebaseCustomToken } from "./privy-firebase-bridge";

// User functions - essential for onboarding
export { updateWalletAddress } from "./users/update-wallet-address";
export { checkUsernameAvailability } from "./users/check-username-availability";
export { updateUsername } from "./users/update-username";
export { deleteUserAccount } from "./users/delete-user-account";

// Utility
export { getFeePayerAddress } from "./utils/get-fee-payer-address";

// ============================================
// PREDICTION MARKETS - Core Feature
// ============================================

// Smart money wallets (admin manages the curated list)
export { getSmartMoneyWallets, addSmartMoneyWallet, removeSmartMoneyWallet, seedSmartMoneyWallets } from "./prediction/smart-money-wallets";

// Prediction webhook (receives Helius transactions for smart money bets)
export { predictionWebhook } from "./prediction/prediction-webhook";

// Scheduled bet resolution (checks market outcomes hourly)
export { resolvePredictionBets } from "./prediction/resolve-prediction-bets";

// Leaderboard sync (auto-discovers top traders from Jupiter)
export { syncLeaderboard, syncLeaderboardNow } from "./prediction/sync-leaderboard";

// Historical backfill (fetch past bets when adding wallets)
export { backfillWalletHistory } from "./prediction/backfill-history";

// Market title backfill (fix bets with missing titles)
export { backfillMarketTitles } from "./prediction/backfill-market-titles";

// Polling backup (catches missed webhook events)
export { pollRecentTransactions } from "./prediction/poll-transactions";

// Stats calculation (hourly recalculation of win rates, P&L, ROI)
export { calculateOnChainStats } from "./prediction/calculate-stats";

// ============================================
// POLYMARKET CROSS-REFERENCE
// ============================================

// Polymarket market sync (hourly sync + manual trigger)
export { syncPolymarketMarkets, syncPolymarketNow } from "./prediction/polymarket-sync";

// Cross-platform signals (processes signals, serves to iOS)
export { processPolymarketSignals, getCrossPlatformSignals, getMatchedMarkets, cleanupPolymarketData } from "./prediction/polymarket-signals";

// ============================================
// PREDICTION COPY TRADING - Auto-copy with Privy delegation
// ============================================

// Delegation management (enable/disable server-side copy execution)
export { approvePredictionDelegation, revokePredictionDelegation } from "./prediction/approve-prediction-delegation";

// Server-side copy execution (uses Privy auth key to sign on behalf of user)
export { executePredictionCopyServer } from "./prediction/execute-prediction-copy-server";

// ============================================
// DISABLED FUNCTIONS (re-enable as needed)
// ============================================

// User functions - not needed for MVP
// export { getRecentRecipients } from "./users/get-recent-recipients";
// export { addDevContact } from "./users/add-dev-contact";
export { createServerWallet } from "./users/create-server-wallet";
// export { getUserActivity } from "./users/get-user-activity";

// Utility - not needed
// export { setupWickettTeamUser } from "./utils/get-fee-payer-address";

// V2 Solana transactions - not needed without send
// export { sponsorSolTransferV2 } from "./transactions/sponsor-sol-transfer-v2";
// export { sponsorSplTransferV2 } from "./transactions/sponsor-spl-transfer-v2";
// export { sponsorJupiterSwap } from "./transactions/sponsor-jupiter-swap";
// export { broadcastSignedTransaction } from "./transactions/broadcast-signed-transaction";

// Monitoring - low priority
// export { monitorFeePayerBalance, checkFeePayerBalance } from "./monitoring/fee-payer-monitor";

// Payment requests - not needed
// export { createPaymentRequest } from "./requests/create-payment-request";
// export { createAndSendFiatRequest } from "./requests/create-and-send-fiat-request";
// export { getPaymentRequest } from "./requests/get-payment-request";
// export { searchUsers } from "./requests/search-users";
// export { fulfillPaymentRequest } from "./requests/fulfill-payment-request";
// export { rejectPaymentRequest } from "./requests/reject-payment-request";
// export { getMyRequests } from "./requests/get-my-requests";
// export { getReceivedRequests } from "./requests/get-received-requests";
// export { processPaymentRequest } from "./requests/process-payment-request";

// Jupiter swap - optional, can re-enable
// export { getJupiterQuote } from "./solana/get-jupiter-quote";
// export { getJupiterSwapTransaction } from "./solana/get-jupiter-swap-transaction";
// export { executeJupiterSwap } from "./solana/execute-jupiter-swap";

// Delegation - re-enabled for copy trading
export { approveDelegationV2 } from "./delegation/approve-delegation-v2";
// export { confirmDelegation } from "./delegation/confirm-delegation";
export { revokeDelegationV2 } from "./delegation/revoke-delegation-v2";
export { getDelegationStatus } from "./delegation/get-delegation-status";

// Helius payment webhook - replaced by prediction webhook
// export { heliusPaymentWebhook } from "./webhooks/helius-payment-webhook";

// Coinbase - optional, can re-enable
// export { createCoinbaseOnrampSession } from "./coinbase/create-onramp-session";
// export { createCoinbaseApplePayOrder } from "./coinbase/create-apple-pay-order";
// export { createCoinbaseOfframpSession } from "./coinbase/create-offramp-session";
// export { getCoinbaseTransferStatus } from "./coinbase/get-transfer-status";
// export { coinbaseWebhook } from "./coinbase/coinbase-webhook";
// export { adminGetCoinbaseTransactions, adminSyncCoinbaseSession, adminUpdateSessionStatus } from "./coinbase/admin-get-transactions";
// export { adminRegisterCoinbaseWebhook, adminListCoinbaseWebhooks } from "./coinbase/register-webhook";

// Admin/insights - dev tools
// export { generateInsights, getAggregatedData } from "./admin/generate-insights";
// export { dailyInsightsEmail, sendInsightsEmailNow } from "./admin/scheduled-insights";

// Copy trading - re-enabled for Mimic
export { addTrackedWallet } from "./tracking/add-tracked-wallet";
export { removeTrackedWallet } from "./tracking/remove-tracked-wallet";
export { tradeWebhook } from "./tracking/trade-webhook";
export { executeCopyTrade } from "./tracking/execute-copy-trade";
