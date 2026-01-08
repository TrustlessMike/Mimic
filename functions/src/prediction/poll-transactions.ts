/**
 * Poll recent transactions as backup to webhook
 * Catches any missed events from Helius webhook
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
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

/**
 * Poll recent transactions every 5 minutes as backup to webhook
 */
export const pollRecentTransactions = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "America/New_York",
    secrets: [HELIUS_API_KEY],
    retryCount: 2,
  },
  async () => {
    logger.info("Polling for recent prediction transactions...");

    // Get all active smart money wallets
    const walletsSnapshot = await db
      .collection("smart_money_wallets")
      .where("isActive", "==", true)
      .get();

    if (walletsSnapshot.empty) {
      logger.info("No wallets to poll");
      return;
    }

    logger.info(`Polling ${walletsSnapshot.size} wallets...`);

    let newBetsFound = 0;
    let walletsChecked = 0;

    for (const walletDoc of walletsSnapshot.docs) {
      const wallet = walletDoc.data();

      try {
        // Fetch last 10 transactions (covers 5 min window typically)
        const recentTxs = await fetchRecentTransactions(
          wallet.address,
          HELIUS_API_KEY.value()
        );

        for (const tx of recentTxs) {
          // Skip if already stored
          const existing = await db.collection("prediction_bets").doc(tx.signature).get();
          if (existing.exists) continue;

          // Parse bet from transaction
          const bet = await parsePredictionTransaction(tx, wallet.address);
          if (!bet) continue;

          // Add wallet nickname
          bet.walletNickname = wallet.nickname;

          // Fetch market info
          const marketInfo = await fetchMarketInfo(bet.marketAddress);
          if (marketInfo) {
            bet.marketTitle = marketInfo.title;
            bet.marketCategory = marketInfo.category;
          }

          // Store bet
          await db.collection("prediction_bets").doc(tx.signature).set({
            ...bet,
            source: "polling", // Mark as from polling (vs webhook)
            createdAt: FieldValue.serverTimestamp(),
          });

          newBetsFound++;
          logger.info(`Found missed bet via polling: ${tx.signature.slice(0, 16)}...`);
        }

        walletsChecked++;
      } catch (error) {
        logger.error(`Error polling wallet ${wallet.address}:`, error);
      }

      // Rate limit: wait 100ms between wallets
      await new Promise((resolve) => setTimeout(resolve, 100));
    }

    logger.info(`Polling complete. Checked ${walletsChecked} wallets, found ${newBetsFound} new bets.`);
  }
);

/**
 * Fetch recent transactions for a wallet from Helius
 */
async function fetchRecentTransactions(
  wallet: string,
  apiKey: string
): Promise<HeliusTransaction[]> {
  const url = `https://api.helius.xyz/v0/addresses/${wallet}/transactions?api-key=${apiKey}&limit=10`;

  const response = await fetch(url);

  if (!response.ok) {
    throw new Error(`Helius API error: ${response.status}`);
  }

  const transactions = (await response.json()) as HeliusTransaction[];

  // Filter for Jupiter Prediction program
  return transactions.filter((tx) =>
    tx.instructions?.some((ix) => ix.programId === JUPITER_PREDICTION_PROGRAM)
  );
}

/**
 * Parse a prediction bet from transaction
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
  status: string;
  canCopy: boolean;
} | null> {
  try {
    const predictionInstruction = tx.instructions?.find(
      (ix) => ix.programId === JUPITER_PREDICTION_PROGRAM
    );

    if (!predictionInstruction) {
      return null;
    }

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

    if (amount === 0) {
      return null;
    }

    // Calculate average price
    let avgPrice = 0.5;
    if (sharesReceived > 0 && usdcSpent > 0) {
      avgPrice = usdcSpent / sharesReceived;
      if (avgPrice > 1) avgPrice = 1;
    }
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
      status: isPlacingBet ? "open" : "claimed",
      canCopy: isPlacingBet,
    };
  } catch (error) {
    logger.error(`Error parsing transaction ${tx.signature}:`, error);
    return null;
  }
}

/**
 * Determine YES/NO direction from outcome token
 */
async function determineDirection(
  outcomeToken: string,
  marketAddress: string
): Promise<BetDirection> {
  const marketDoc = await db.collection("prediction_markets").doc(marketAddress).get();

  if (marketDoc.exists) {
    const data = marketDoc.data();
    if (data?.yesToken === outcomeToken) return "YES";
    if (data?.noToken === outcomeToken) return "NO";
  }

  const marketInfo = await fetchMarketInfo(marketAddress);
  if (marketInfo) {
    if (marketInfo.yesToken === outcomeToken) return "YES";
    if (marketInfo.noToken === outcomeToken) return "NO";
  }

  return "YES";
}

/**
 * Fetch market info from Jupiter API
 */
async function fetchMarketInfo(marketAddress: string): Promise<{
  id: string;
  title: string;
  category?: string;
  yesToken: string;
  noToken: string;
} | null> {
  try {
    const cached = await db.collection("prediction_markets").doc(marketAddress).get();
    if (cached.exists) {
      const data = cached.data();
      const cacheAge = Date.now() - (data?.cachedAt?.toMillis() || 0);
      if (cacheAge < 3600000) {
        return data as {
          id: string;
          title: string;
          category?: string;
          yesToken: string;
          noToken: string;
        };
      }
    }

    const response = await fetch(`${JUPITER_MARKETS_API}/markets/${marketAddress}`);

    if (!response.ok) {
      return null;
    }

    const market = await response.json();

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
