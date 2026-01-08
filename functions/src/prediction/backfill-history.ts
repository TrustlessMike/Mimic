/**
 * Backfill historical bets for a smart money wallet
 * Uses Helius parsed transaction history API
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { defineSecret } from "firebase-functions/params";
import {
  JUPITER_PREDICTION_PROGRAM,
  USDC_MINT,
  BetDirection,
} from "./prediction-config";

const db = getFirestore();
const HELIUS_API_KEY = defineSecret("HELIUS_API_KEY");
const JUPITER_MARKETS_API = "https://markets-api.jup.ag";

interface HeliusTransaction {
  signature: string;
  timestamp: number;
  type: string;
  feePayer: string;
  instructions?: Array<{
    programId: string;
    accounts: string[];
    data: string;
  }>;
  accountData?: Array<{
    account: string;
    nativeBalanceChange: number;
    tokenBalanceChanges: Array<{
      mint: string;
      rawTokenAmount: {
        tokenAmount: string;
        decimals: number;
      };
      userAccount: string;
    }>;
  }>;
}

interface JupiterMarket {
  id: string;
  title: string;
  category?: string;
  yesToken: string;
  noToken: string;
}

/**
 * Backfill historical bets for a wallet - admin only
 */
export const backfillWalletHistory = onCall(
  {
    secrets: [HELIUS_API_KEY],
    timeoutSeconds: 540, // 9 minutes for large histories
    cors: true,
  },
  async (request) => {
    const { walletAddress, maxTransactions = 200 } = request.data;

    // Admin check
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.data()?.isAdmin !== true) {
      throw new HttpsError("permission-denied", "Admin access required");
    }

    if (!walletAddress || typeof walletAddress !== "string") {
      throw new HttpsError("invalid-argument", "Wallet address required");
    }

    logger.info(`Backfilling history for ${walletAddress}, max ${maxTransactions} txs`);

    try {
      // Fetch transaction history from Helius
      const transactions = await fetchWalletTransactions(
        walletAddress,
        HELIUS_API_KEY.value(),
        maxTransactions
      );

      logger.info(`Found ${transactions.length} prediction transactions for ${walletAddress}`);

      let betsAdded = 0;
      let betsSkipped = 0;
      let parseErrors = 0;

      // Get wallet nickname from smart_money_wallets
      let walletNickname: string | null = null;
      const walletDoc = await db
        .collection("smart_money_wallets")
        .where("address", "==", walletAddress)
        .where("isActive", "==", true)
        .limit(1)
        .get();

      if (!walletDoc.empty) {
        walletNickname = walletDoc.docs[0].data().nickname;
      }

      for (const tx of transactions) {
        // Check if already exists
        const existing = await db.collection("prediction_bets").doc(tx.signature).get();
        if (existing.exists) {
          betsSkipped++;
          continue;
        }

        // Parse bet from transaction
        const bet = await parsePredictionTransaction(tx, walletAddress);
        if (!bet) {
          parseErrors++;
          continue;
        }

        // Add wallet nickname
        bet.walletNickname = walletNickname;

        // Fetch market info
        const marketInfo = await fetchMarketInfo(bet.marketAddress);
        if (marketInfo) {
          bet.marketTitle = marketInfo.title;
          bet.marketCategory = marketInfo.category;
        }

        // Store bet
        await db.collection("prediction_bets").doc(tx.signature).set({
          ...bet,
          backfilled: true,
          createdAt: FieldValue.serverTimestamp(),
        });

        betsAdded++;
      }

      // Recalculate wallet stats
      await recalculateWalletStats(walletAddress);

      logger.info(
        `Backfill complete for ${walletAddress}: ${betsAdded} added, ${betsSkipped} skipped, ${parseErrors} parse errors`
      );

      return {
        success: true,
        betsAdded,
        betsSkipped,
        parseErrors,
        totalTransactions: transactions.length,
      };
    } catch (error) {
      logger.error(`Backfill error for ${walletAddress}:`, error);
      throw new HttpsError("internal", "Backfill failed");
    }
  }
);

/**
 * Fetch wallet transactions from Helius API
 */
async function fetchWalletTransactions(
  wallet: string,
  apiKey: string,
  limit: number
): Promise<HeliusTransaction[]> {
  const allTransactions: HeliusTransaction[] = [];
  let beforeSignature: string | undefined;

  // Paginate through transactions
  while (allTransactions.length < limit) {
    const batchSize = Math.min(100, limit - allTransactions.length);
    let url = `https://api.helius.xyz/v0/addresses/${wallet}/transactions?api-key=${apiKey}&limit=${batchSize}`;

    if (beforeSignature) {
      url += `&before=${beforeSignature}`;
    }

    const response = await fetch(url);

    if (!response.ok) {
      throw new Error(`Helius API error: ${response.status}`);
    }

    const transactions = (await response.json()) as HeliusTransaction[];

    if (transactions.length === 0) {
      break;
    }

    // Filter for Jupiter Prediction program transactions
    const predictionTxs = transactions.filter((tx) =>
      tx.instructions?.some((ix) => ix.programId === JUPITER_PREDICTION_PROGRAM)
    );

    allTransactions.push(...predictionTxs);

    // Set pagination cursor
    beforeSignature = transactions[transactions.length - 1].signature;

    // If we got fewer than requested, we've reached the end
    if (transactions.length < batchSize) {
      break;
    }

    // Rate limit: wait 200ms between requests
    await new Promise((resolve) => setTimeout(resolve, 200));
  }

  return allTransactions;
}

/**
 * Parse a prediction bet from a Helius transaction
 */
async function parsePredictionTransaction(
  tx: HeliusTransaction,
  walletAddress: string
): Promise<{
  walletAddress: string;
  walletNickname?: string | null;
  signature: string;
  timestamp: Date;
  marketAddress: string;
  marketTitle?: string;
  marketCategory?: string;
  direction: BetDirection;
  amount: number;
  shares: number;
  avgPrice: number;
  sharesEstimated?: boolean;
  status: string;
  canCopy: boolean;
} | null> {
  try {
    // Find the prediction instruction
    const predictionInstruction = tx.instructions?.find(
      (ix) => ix.programId === JUPITER_PREDICTION_PROGRAM
    );

    if (!predictionInstruction) {
      return null;
    }

    // Instruction accounts layout:
    // 0: User wallet
    // 1: Market/Pool account
    // 2: User's position account
    // 3: Outcome token (YES or NO mint)
    const marketAddress = predictionInstruction.accounts[1];
    const outcomeToken = predictionInstruction.accounts[3];

    // Find USDC and outcome token changes for the USER only
    let usdcSpent = 0;
    let usdcReceived = 0;
    let sharesReceived = 0;

    for (const account of tx.accountData || []) {
      for (const change of account.tokenBalanceChanges || []) {
        const amount = parseFloat(change.rawTokenAmount.tokenAmount);
        const decimals = change.rawTokenAmount.decimals;
        const value = amount / Math.pow(10, decimals);

        // Only count changes for the user (userAccount matches walletAddress)
        const isUserAccount = change.userAccount === walletAddress;
        if (!isUserAccount) continue;

        // USDC changes
        if (change.mint === USDC_MINT) {
          if (value < 0) {
            usdcSpent += Math.abs(value);
          } else if (value > 0) {
            usdcReceived += value;
          }
        }

        // Outcome token changes - positive = receiving shares
        if (change.mint === outcomeToken && value > 0) {
          sharesReceived += value;
        }
      }
    }

    const isPlacingBet = usdcSpent > usdcReceived;
    const amount = isPlacingBet ? usdcSpent : usdcReceived;

    // Skip transactions with no USDC movement (not a bet)
    if (amount === 0) {
      return null;
    }

    // Calculate average price
    let avgPrice = 0.5;
    let sharesEstimated = false;

    if (sharesReceived > 0 && usdcSpent > 0) {
      avgPrice = usdcSpent / sharesReceived;
      if (avgPrice > 1) avgPrice = 1;
    } else if (usdcSpent > 0 && sharesReceived === 0) {
      // Shares were minted (not transferred), estimate based on default price
      sharesReceived = usdcSpent / avgPrice;
      sharesEstimated = true;
    }

    // Determine YES/NO direction
    const direction = await determineDirection(outcomeToken, marketAddress);

    return {
      walletAddress: tx.feePayer,
      signature: tx.signature,
      timestamp: new Date(tx.timestamp * 1000),
      marketAddress,
      direction,
      amount,
      shares: sharesReceived,
      avgPrice,
      sharesEstimated,
      status: isPlacingBet ? "open" : "claimed",
      canCopy: isPlacingBet, // Only copy new bets
    };
  } catch (error) {
    logger.error(`Error parsing transaction ${tx.signature}:`, error);
    return null;
  }
}

/**
 * Determine if the outcome token is YES or NO
 */
async function determineDirection(
  outcomeToken: string,
  marketAddress: string
): Promise<BetDirection> {
  // Try to get from cache first
  const marketDoc = await db.collection("prediction_markets").doc(marketAddress).get();

  if (marketDoc.exists) {
    const data = marketDoc.data();
    if (data?.yesToken === outcomeToken) return "YES";
    if (data?.noToken === outcomeToken) return "NO";
  }

  // Try to fetch from Jupiter API
  const marketInfo = await fetchMarketInfo(marketAddress);
  if (marketInfo) {
    if (marketInfo.yesToken === outcomeToken) return "YES";
    if (marketInfo.noToken === outcomeToken) return "NO";
  }

  // Default to YES if we can't determine
  logger.warn(`Could not determine direction for token ${outcomeToken} in market ${marketAddress}`);
  return "YES";
}

/**
 * Fetch market information from Jupiter Prediction API
 */
async function fetchMarketInfo(marketAddress: string): Promise<JupiterMarket | null> {
  try {
    // Check cache first
    const cached = await db.collection("prediction_markets").doc(marketAddress).get();
    if (cached.exists) {
      const data = cached.data();
      // Return cached if less than 1 hour old
      const cacheAge = Date.now() - (data?.cachedAt?.toMillis() || 0);
      if (cacheAge < 3600000) {
        return data as JupiterMarket;
      }
    }

    // Fetch from Jupiter API
    const response = await fetch(`${JUPITER_MARKETS_API}/markets/${marketAddress}`);

    if (!response.ok) {
      logger.warn(`Jupiter API returned ${response.status} for market ${marketAddress}`);
      return null;
    }

    const market = (await response.json()) as JupiterMarket;

    // Cache the market data
    await db
      .collection("prediction_markets")
      .doc(marketAddress)
      .set(
        {
          ...market,
          cachedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    return market;
  } catch (error) {
    logger.error(`Error fetching market info for ${marketAddress}:`, error);
    return null;
  }
}

/**
 * Recalculate wallet stats from all stored bets
 */
async function recalculateWalletStats(walletAddress: string): Promise<void> {
  try {
    // Get all bets for this wallet
    const betsSnapshot = await db
      .collection("prediction_bets")
      .where("walletAddress", "==", walletAddress)
      .get();

    let totalBets = 0;
    let wins = 0;
    let totalPnl = 0;
    let totalAmount = 0;

    for (const betDoc of betsSnapshot.docs) {
      const bet = betDoc.data();
      if (bet.status === "open" || bet.status === "won" || bet.status === "lost") {
        totalBets++;
        totalAmount += bet.amount || 0;

        if (bet.status === "won") {
          wins++;
          totalPnl += bet.pnl || 0;
        } else if (bet.status === "lost") {
          totalPnl += bet.pnl || 0; // Negative
        }
      }
    }

    // Only count resolved bets for win rate
    const resolvedBets = betsSnapshot.docs.filter(
      (doc) => doc.data().status === "won" || doc.data().status === "lost"
    ).length;

    const winRate = resolvedBets > 0 ? wins / resolvedBets : 0;
    const avgBetSize = totalBets > 0 ? totalAmount / totalBets : 0;

    // Update smart money wallet document
    const walletQuery = await db
      .collection("smart_money_wallets")
      .where("address", "==", walletAddress)
      .where("isActive", "==", true)
      .get();

    if (!walletQuery.empty) {
      const walletDoc = walletQuery.docs[0];
      await walletDoc.ref.update({
        "stats.totalBets": totalBets,
        "stats.winRate": winRate,
        "stats.totalPnl": totalPnl,
        "stats.avgBetSize": avgBetSize,
        "stats.wins": wins,
        "stats.losses": resolvedBets - wins,
        "stats.lastCalculatedAt": FieldValue.serverTimestamp(),
      });

      logger.info(
        `Recalculated stats for ${walletAddress}: ${totalBets} bets, ${(winRate * 100).toFixed(1)}% win rate`
      );
    }
  } catch (error) {
    logger.error(`Error recalculating stats for ${walletAddress}:`, error);
  }
}
