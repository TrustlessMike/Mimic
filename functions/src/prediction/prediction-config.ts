/**
 * Jupiter Prediction Markets Configuration
 */

// Jupiter Prediction Program ID
export const JUPITER_PREDICTION_PROGRAM = "3ZZuTbwC6aJbvteyVxXUS7gtFYdf7AuXeitx6VyvjvUp";

// USDC mint (used for all bets)
export const USDC_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v";

/**
 * Prediction bet types
 */
export type BetDirection = "YES" | "NO";
export type BetStatus = "open" | "won" | "lost" | "claimed";

/**
 * Known instruction discriminators (first 8 bytes of instruction data, hex encoded)
 */
export const INSTRUCTION_DISCRIMINATORS = {
  BET_PLACEMENT: "8d3625cfedd2fad7", // Market order bet placement
  CLAIM: "5a67d11c073fa804", // Claim winnings
  LIMIT_ORDER: "b3c9dd165b10d004", // Limit order placement
  CANCEL: "7ff0843ee3c69285", // Cancel order
};

/**
 * Prediction market bet
 */
export interface PredictionBet {
  id: string;
  walletAddress: string;
  walletNickname?: string;
  signature: string;
  timestamp: Date;

  // Market info
  marketAddress: string;
  marketTitle?: string;
  marketCategory?: string;

  // Bet details
  direction: BetDirection;
  amount: number; // USDC amount
  shares: number; // Number of YES/NO shares received
  avgPrice: number; // Price per share (0-1)
  sharesEstimated?: boolean; // True if shares were estimated (minted tokens don't show in Helius)

  // Status
  status: BetStatus;
  pnl?: number; // Profit/loss if resolved

  // Tracking
  canCopy: boolean;
  verified?: boolean; // True if direction was verified on-chain
  confidence?: "high" | "medium" | "low"; // How confident we are in the direction
  // high = verified on-chain in real-time
  // medium = from cached registry (previously verified)
  // low = legacy data (should not happen for new bets)
}

/**
 * Tracked predictor (whale we're following)
 */
export interface TrackedPredictor {
  id: string;
  userId: string;
  walletAddress: string;
  nickname?: string;
  createdAt: Date;
  stats: PredictorStats;
}

/**
 * Predictor statistics
 */
export interface PredictorStats {
  totalBets: number;
  winRate: number;
  totalPnl: number;
  avgBetSize: number;
  lastBetAt?: Date;
}

/**
 * Platform fees for prediction copy betting
 */
export const PREDICTION_FEES = {
  COPY_BET_BPS: 50, // 0.5% on copy bets
};
