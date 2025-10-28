import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// Export Cloud Functions
export { createFirebaseCustomToken } from "./privy-firebase-bridge";

// Export Solana transaction functions
export { sponsorSolTransfer } from "./transactions/sponsor-sol-transfer";
export { sponsorSplTransfer } from "./transactions/sponsor-spl-transfer";
export { sponsorJupiterSwap } from "./transactions/sponsor-jupiter-swap";
export { sponsorCustomInstruction } from "./transactions/sponsor-custom-instruction";

// Export monitoring functions
export {
  monitorFeePayerBalance,
  checkFeePayerBalance
} from "./monitoring/fee-payer-monitor";
