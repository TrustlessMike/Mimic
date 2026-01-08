/**
 * Prediction Market Webhook Handler
 *
 * Receives Helius enhanced transactions for Jupiter Prediction program
 * and stores bets in Firestore for the feed.
 *
 * Features:
 * - Parses bet data from transactions
 * - Fetches market title/category from Jupiter API
 * - Sends push notifications to users tracking the wallet
 */

import { onRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import { defineSecret } from "firebase-functions/params";
import {
  JUPITER_PREDICTION_PROGRAM,
  USDC_MINT,
  PredictionBet,
  BetDirection,
} from "./prediction-config";
import { KALSHI_API } from "./kalshi-config";

const db = getFirestore();

// Webhook secret for verification
export const PREDICTION_WEBHOOK_SECRET = defineSecret("PREDICTION_WEBHOOK_SECRET");

// Jupiter Prediction Markets API
const JUPITER_MARKETS_API = "https://markets-api.jup.ag";

interface HeliusTransaction {
  signature: string;
  timestamp: number;
  type: string;
  feePayer: string;
  source?: string;
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
  instructions?: Array<{
    programId: string;
    accounts: string[];
    data: string;
  }>;
  events?: {
    swap?: any;
  };
}

interface JupiterMarket {
  id: string;
  eventId?: string;  // Kalshi market ticker
  title: string;
  description?: string;
  category?: string;
  status: string;
  yesToken: string;
  noToken: string;
  yesPrice: number;
  noPrice: number;
  endTime?: string;
  resolved?: boolean;
  outcome?: "YES" | "NO";
}

interface KalshiMarketData {
  ticker: string;
  yesBid: number;
  yesAsk: number;
  midPrice: number;
  spread: number;
  volume: number;
  lastPrice: number;
}

/**
 * Webhook endpoint for Helius prediction transactions
 */
export const predictionWebhook = onRequest(
  {
    secrets: [PREDICTION_WEBHOOK_SECRET],
    cors: false,
    invoker: "public",
  },
  async (req, res) => {
    try {
      // Verify webhook secret
      const authHeader = req.headers.authorization;
      const expectedSecret = PREDICTION_WEBHOOK_SECRET.value();

      if (authHeader !== `Bearer ${expectedSecret}`) {
        logger.warn("Unauthorized prediction webhook attempt");
        res.status(401).send("Unauthorized");
        return;
      }

      // Parse transactions
      const transactions: HeliusTransaction[] = req.body;

      if (!Array.isArray(transactions) || transactions.length === 0) {
        res.status(200).send("No transactions");
        return;
      }

      logger.info(`Processing ${transactions.length} prediction transactions`);

      let processedCount = 0;

      for (const tx of transactions) {
        try {
          // Check if this is a Jupiter Prediction transaction
          const predictionInstruction = tx.instructions?.find(
            (ix) => ix.programId === JUPITER_PREDICTION_PROGRAM
          );

          if (!predictionInstruction) {
            continue;
          }

          // Check if this is a smart money wallet we're tracking
          const smartMoneySnapshot = await db
            .collection("smart_money_wallets")
            .where("address", "==", tx.feePayer)
            .where("isActive", "==", true)
            .get();

          if (smartMoneySnapshot.empty) {
            logger.debug(`Wallet not in smart money list: ${tx.feePayer}`);
            continue;
          }

          // Parse the bet from the transaction
          const bet = await parsePredictionBet(tx, predictionInstruction);

          if (!bet) {
            logger.warn(`Could not parse bet from tx: ${tx.signature}`);
            continue;
          }

          // Add wallet nickname from smart money list
          const smartMoneyWallet = smartMoneySnapshot.docs[0].data();
          bet.walletNickname = smartMoneyWallet.nickname;

          // Fetch market info from Jupiter API
          const marketInfo = await fetchMarketInfo(bet.marketAddress);
          let kalshiData: KalshiMarketData | null = null;

          if (marketInfo) {
            bet.marketTitle = marketInfo.title;
            bet.marketCategory = marketInfo.category;

            // Cache market data for future lookups
            await cacheMarketData(bet.marketAddress, marketInfo);

            // Fetch Kalshi price at time of trade for context
            if (marketInfo.eventId) {
              kalshiData = await fetchKalshiPrice(marketInfo.eventId);
            }
          }

          // Store in Firestore with Kalshi data
          const betRef = await db.collection("prediction_bets").doc(tx.signature).set({
            ...bet,
            createdAt: FieldValue.serverTimestamp(),
            // Kalshi market data at time of trade
            ...(kalshiData && {
              kalshiTicker: kalshiData.ticker,
              kalshiYesBid: kalshiData.yesBid,
              kalshiYesAsk: kalshiData.yesAsk,
              kalshiMidPrice: kalshiData.midPrice,
              kalshiSpread: kalshiData.spread,
              kalshiVolume: kalshiData.volume,
            }),
          });

          // Update smart money wallet stats
          await updateSmartMoneyStats(tx.feePayer, bet, smartMoneySnapshot.docs[0].id);

          // Send push notifications to ALL users (global feed)
          if (bet.status === "open") {
            await sendBetNotifications(tx.feePayer, bet);
          }

          processedCount++;
          const kalshiInfo = kalshiData ? ` (Kalshi: ${(kalshiData.midPrice * 100).toFixed(0)}¢)` : "";
          logger.info(
            `Stored prediction bet: ${bet.direction} $${bet.amount.toFixed(2)} on ${bet.marketTitle || bet.marketAddress}${kalshiInfo}`
          );
        } catch (error) {
          logger.error(`Error processing tx ${tx.signature}:`, error);
        }
      }

      logger.info(`Processed ${processedCount} prediction bets`);
      res.status(200).send(`Processed ${processedCount} bets`);
    } catch (error) {
      logger.error("Prediction webhook error:", error);
      res.status(500).send("Internal error");
    }
  }
);

/**
 * Fetch market information from Jupiter Prediction API
 */
async function fetchMarketInfo(marketAddress: string): Promise<JupiterMarket | null> {
  try {
    // First check cache
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

    const market = await response.json() as JupiterMarket;
    return market;
  } catch (error) {
    logger.error(`Error fetching market info for ${marketAddress}:`, error);
    return null;
  }
}

/**
 * Cache market data in Firestore for faster lookups
 */
async function cacheMarketData(marketAddress: string, market: JupiterMarket): Promise<void> {
  try {
    await db.collection("prediction_markets").doc(marketAddress).set({
      ...market,
      cachedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (error) {
    logger.error(`Error caching market data for ${marketAddress}:`, error);
  }
}

/**
 * Update smart money wallet stats after a bet
 */
async function updateSmartMoneyStats(
  walletAddress: string,
  bet: Omit<PredictionBet, "id">,
  walletDocId: string
): Promise<void> {
  try {
    const walletRef = db.collection("smart_money_wallets").doc(walletDocId);

    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(walletRef);
      const stats = doc.data()?.stats || {
        totalBets: 0,
        winRate: 0,
        totalPnl: 0,
        avgBetSize: 0,
      };

      const newTotalBets = stats.totalBets + 1;
      const newTotalVolume = stats.avgBetSize * stats.totalBets + bet.amount;

      transaction.update(walletRef, {
        "stats.totalBets": newTotalBets,
        "stats.avgBetSize": newTotalVolume / newTotalBets,
        "stats.lastBetAt": FieldValue.serverTimestamp(),
      });
    });
  } catch (error) {
    logger.error("Error updating smart money stats:", error);
  }
}

/**
 * Send push notifications to ALL app users (global smart money feed)
 */
async function sendBetNotifications(
  walletAddress: string,
  bet: Omit<PredictionBet, "id">
): Promise<void> {
  try {
    // Get FCM tokens from ALL users who have notifications enabled
    const usersSnapshot = await db.collection("users")
      .where("notificationsEnabled", "==", true)
      .get();

    const tokens: string[] = [];
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        tokens.push(...userData.fcmTokens);
      }
    }

    if (tokens.length === 0) {
      logger.debug("No FCM tokens found for notification");
      return;
    }

    // Limit to 500 tokens per multicast (FCM limit)
    const tokenBatches = [];
    for (let i = 0; i < tokens.length; i += 500) {
      tokenBatches.push(tokens.slice(i, i + 500));
    }

    // Create notification
    const displayName = bet.walletNickname || shortenAddress(walletAddress);
    const marketTitle = bet.marketTitle || "a prediction market";
    const amount = bet.amount.toFixed(2);

    let totalSuccess = 0;
    let totalFailed = 0;
    const allInvalidTokens: string[] = [];

    // Send notifications in batches
    for (const batchTokens of tokenBatches) {
      const message = {
        tokens: batchTokens,
        notification: {
          title: `${displayName} placed a bet`,
          body: `${bet.direction} on "${marketTitle}" - $${amount}`,
        },
        data: {
          type: "new_prediction_bet",
          signature: bet.signature,
          walletAddress,
          direction: bet.direction,
          amount: amount,
          marketAddress: bet.marketAddress,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await getMessaging().sendEachForMulticast(message);
      totalSuccess += response.successCount;
      totalFailed += response.failureCount;

      // Collect invalid tokens
      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error?.code === "messaging/registration-token-not-registered") {
          allInvalidTokens.push(batchTokens[idx]);
        }
      });
    }

    logger.info(`Sent ${totalSuccess} notifications, ${totalFailed} failed`);

    // Clean up invalid tokens
    if (allInvalidTokens.length > 0) {
      await cleanupInvalidTokens(allInvalidTokens);
    }
  } catch (error) {
    logger.error("Error sending bet notifications:", error);
  }
}

/**
 * Remove invalid FCM tokens from user documents
 */
async function cleanupInvalidTokens(invalidTokens: string[]): Promise<void> {
  try {
    const usersSnapshot = await db.collection("users").get();
    const batch = db.batch();

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        const validTokens = userData.fcmTokens.filter(
          (token: string) => !invalidTokens.includes(token)
        );
        if (validTokens.length !== userData.fcmTokens.length) {
          batch.update(userDoc.ref, { fcmTokens: validTokens });
        }
      }
    }

    await batch.commit();
    logger.info(`Cleaned up ${invalidTokens.length} invalid FCM tokens`);
  } catch (error) {
    logger.error("Error cleaning up invalid tokens:", error);
  }
}

/**
 * Shorten a Solana address for display
 */
function shortenAddress(address: string): string {
  return `${address.slice(0, 4)}...${address.slice(-4)}`;
}

/**
 * Parse a prediction bet from a Helius transaction
 */
async function parsePredictionBet(
  tx: HeliusTransaction,
  instruction: { programId: string; accounts: string[]; data: string }
): Promise<Omit<PredictionBet, "id"> | null> {
  try {
    // Instruction accounts layout (based on your tx):
    // 0: User wallet
    // 1: Market/Pool account
    // 2: User's position account
    // 3: Outcome token (YES or NO mint)
    // 4: User's USDC ATA
    // 5: Pool's USDC ATA
    // 6: Token Program

    const userWallet = instruction.accounts[0];
    const marketAddress = instruction.accounts[1];
    const outcomeToken = instruction.accounts[3];

    // Find USDC balance change to determine bet amount
    let usdcChange = 0;
    let sharesReceived = 0;

    for (const account of tx.accountData || []) {
      for (const change of account.tokenBalanceChanges || []) {
        if (change.mint === USDC_MINT && change.userAccount === userWallet) {
          const amount = parseFloat(change.rawTokenAmount.tokenAmount);
          const decimals = change.rawTokenAmount.decimals;
          usdcChange = amount / Math.pow(10, decimals);
        }
        // Track outcome token changes for shares
        if (change.mint === outcomeToken && change.userAccount === userWallet) {
          const amount = parseFloat(change.rawTokenAmount.tokenAmount);
          const decimals = change.rawTokenAmount.decimals;
          sharesReceived = Math.abs(amount / Math.pow(10, decimals));
        }
      }
    }

    // Determine bet direction and type based on USDC flow
    // Negative USDC = placing a bet (buying shares)
    // Positive USDC = claiming winnings or closing position
    const isPlacingBet = usdcChange < 0;
    const amount = Math.abs(usdcChange);

    // Calculate average price if we have shares
    const avgPrice = sharesReceived > 0 ? amount / sharesReceived : 0;

    // Determine YES/NO direction
    const direction: BetDirection = await determineDirection(outcomeToken, marketAddress);

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
      canCopy: isPlacingBet, // Only copy new bets
    };
  } catch (error) {
    logger.error("Error parsing prediction bet:", error);
    return null;
  }
}

/**
 * Fetch Kalshi price data for a market at time of trade
 * Returns current bid/ask/mid prices for context
 */
async function fetchKalshiPrice(eventId: string | undefined): Promise<KalshiMarketData | null> {
  if (!eventId) {
    return null;
  }

  try {
    // Jupiter eventId maps directly to Kalshi market ticker (e.g., "KXSB-26" -> ticker)
    const url = `${KALSHI_API}/markets/${eventId}`;
    const response = await fetch(url);

    if (!response.ok) {
      logger.warn(`Kalshi API returned ${response.status} for market ${eventId}`);
      return null;
    }

    const data = await response.json();
    const market = data.market;

    if (!market) {
      return null;
    }

    // Kalshi prices are in cents (0-100), convert to decimal (0-1)
    const yesBid = (market.yes_bid || 0) / 100;
    const yesAsk = (market.yes_ask || 0) / 100;
    const midPrice = (yesBid + yesAsk) / 2;
    const spread = yesAsk - yesBid;

    return {
      ticker: eventId,
      yesBid,
      yesAsk,
      midPrice,
      spread,
      volume: market.volume || 0,
      lastPrice: (market.last_price || 0) / 100,
    };
  } catch (error) {
    logger.error(`Error fetching Kalshi price for ${eventId}:`, error);
    return null;
  }
}

/**
 * Determine if the outcome token is YES or NO
 * This requires fetching market data or using cached info
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

  // Try to fetch from API
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
 * Update predictor statistics after a bet
 */
async function updatePredictorStats(
  walletAddress: string,
  bet: Omit<PredictionBet, "id">
): Promise<void> {
  try {
    const predictorQuery = await db
      .collection("tracked_predictors")
      .where("walletAddress", "==", walletAddress)
      .limit(1)
      .get();

    if (predictorQuery.empty) return;

    const predictorRef = predictorQuery.docs[0].ref;

    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(predictorRef);
      const stats = doc.data()?.stats || {
        totalBets: 0,
        winRate: 0,
        totalPnl: 0,
        avgBetSize: 0,
      };

      const newTotalBets = stats.totalBets + 1;
      const newTotalVolume = stats.avgBetSize * stats.totalBets + bet.amount;

      transaction.update(predictorRef, {
        "stats.totalBets": newTotalBets,
        "stats.avgBetSize": newTotalVolume / newTotalBets,
        "stats.lastBetAt": FieldValue.serverTimestamp(),
      });
    });
  } catch (error) {
    logger.error("Error updating predictor stats:", error);
  }
}
