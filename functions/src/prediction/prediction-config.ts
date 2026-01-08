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
 * Known instruction discriminators (first 8 bytes of instruction data)
 * These need to be discovered by analyzing transactions
 */
export const INSTRUCTION_DISCRIMINATORS = {
  // TODO: Decode actual discriminators from transactions
  PLACE_BET: "", // Buy YES/NO tokens
  CLAIM_WINNINGS: "NQB4wxbnSoE", // From the tx you shared
  CLOSE_POSITION: "",
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
