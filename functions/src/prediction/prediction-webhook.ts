/**
 * Prediction Market Webhook Handler
 *
 * Receives Helius enhanced transactions for Jupiter Prediction program
 * and stores bets in Firestore for the feed.
 *
 * Features:
 * - Parses bet data from transactions
 * - Uses Market Registry for market metadata (not Jupiter API - doesn't exist)
 * - Fetches live prices from Kalshi API
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
  INSTRUCTION_DISCRIMINATORS,
} from "./prediction-config";
import { KALSHI_API } from "./kalshi-config";
import {
  getMarketMapping,
  getMarketByToken,
  fetchKalshiMarketData,
  MarketMapping,
} from "./market-registry";
import { parseJupiterMarketAccount } from "./jupiter-account-parser";
import { processPredictionCopy, PredictionCopyRequest } from "./execute-prediction-copy";

const db = getFirestore();

// Webhook secret for verification
export const PREDICTION_WEBHOOK_SECRET = defineSecret("PREDICTION_WEBHOOK_SECRET");
const HELIUS_API_KEY = defineSecret("HELIUS_API_KEY");

interface HeliusTransaction {
  signature: string;
  timestamp: number;
  type: string;
  feePayer: string;
  source?: string;
  accountData?: Array<{
    account: string;
    nativeBalanceChange: number;
    tokenBalanceChanges?: Array<{
      mint: string;
      rawTokenAmount: {
        tokenAmount: string;
        decimals: number;
      };
      userAccount: string;
    }>;
  }>;
  // Helius enhanced transactions use tokenTransfers at top level
  tokenTransfers?: Array<{
    fromTokenAccount: string;
    toTokenAccount: string;
    fromUserAccount: string;
    toUserAccount: string;
    tokenAmount: number;
    mint: string;
    tokenStandard: string;
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

interface KalshiMarketData {
  ticker: string;
  title: string;
  category?: string;
  yesBid: number;
  yesAsk: number;
  midPrice: number;
  spread: number;
  volume: number;
}

/**
 * Webhook endpoint for Helius prediction transactions
 */
export const predictionWebhook = onRequest(
  {
    secrets: [PREDICTION_WEBHOOK_SECRET, HELIUS_API_KEY],
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

          // VALIDATION: Get market data from registry (backed by Kalshi)
          const marketMapping = await getMarketMapping(bet.marketAddress);

          // REQUIREMENT 1: Must have Kalshi mapping
          if (!marketMapping) {
            logger.warn(`REJECTED: No market mapping for ${bet.marketAddress}`);
            await flagUnmappedMarket(bet.marketAddress, predictionInstruction.accounts, tx.timestamp);
            continue; // Skip this bet
          }

          // REQUIREMENT 2: Market must be open (not resolved)
          if (marketMapping.status === "resolved") {
            logger.warn(`REJECTED: Market ${bet.marketAddress} is already resolved`);
            continue; // Skip this bet
          }

          // REQUIREMENT 3: Must have valid amount
          if (!bet.amount || bet.amount <= 0) {
            logger.warn(`REJECTED: Invalid amount ${bet.amount} for tx ${tx.signature}`);
            continue; // Skip this bet
          }

          // REQUIREMENT 4: Must have valid shares
          if (!bet.shares || bet.shares <= 0) {
            logger.warn(`REJECTED: Invalid shares ${bet.shares} for tx ${tx.signature}`);
            continue; // Skip this bet
          }

          // All validation passed - enrich with market data
          bet.marketTitle = marketMapping.title;
          bet.marketCategory = marketMapping.category;

          let kalshiData: KalshiMarketData | null = null;

          // Use CACHED Kalshi prices from the mapping (avoid API call per bet)
          if (marketMapping.kalshiMidPrice !== undefined) {
            kalshiData = {
              ticker: marketMapping.kalshiTicker,
              title: marketMapping.title,
              category: marketMapping.category,
              yesBid: marketMapping.kalshiYesBid || 0,
              yesAsk: marketMapping.kalshiYesAsk || 0,
              midPrice: marketMapping.kalshiMidPrice,
              spread: (marketMapping.kalshiYesAsk || 0) - (marketMapping.kalshiYesBid || 0),
              volume: 0,
            };

            // Refine shares estimate if we have market price data
            if (bet.sharesEstimated && bet.amount > 0) {
              const marketPrice = bet.direction === "YES" ? kalshiData.midPrice : (1 - kalshiData.midPrice);
              if (marketPrice && marketPrice > 0 && marketPrice < 1) {
                bet.avgPrice = marketPrice;
                bet.shares = bet.amount / marketPrice;
                logger.info(`Refined shares estimate using cached Kalshi price: ${bet.shares.toFixed(2)} shares at ${(marketPrice * 100).toFixed(1)}¢`);
              }
            }
          }

          // Store validated bet in Firestore
          await db.collection("prediction_bets").doc(tx.signature).set({
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

          // Trigger auto-copy for users following this wallet
          if (bet.canCopy && bet.verified) {
            try {
              const copyRequest: PredictionCopyRequest = {
                userId: "", // Will be filled per-user in processPredictionCopy
                betId: tx.signature,
                trackedWallet: tx.feePayer,
                marketAddress: bet.marketAddress,
                marketTitle: bet.marketTitle,
                direction: bet.direction,
                originalAmount: bet.amount,
                originalPrice: bet.avgPrice,
              };

              const copyResult = await processPredictionCopy(copyRequest);
              if (copyResult.copiesCreated > 0) {
                logger.info(`Auto-copy triggered: ${copyResult.copiesCreated} copies, ${copyResult.notificationsSent} notified`);
              }
            } catch (copyError) {
              logger.error("Error triggering auto-copy:", copyError);
              // Don't fail the main webhook for copy errors
            }
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
 * Flag an unmapped market for auto-discovery
 */
async function flagUnmappedMarket(
  marketAddress: string,
  instructionAccounts: string[],
  timestamp: number
): Promise<void> {
  try {
    const existing = await db.collection("unmapped_markets").doc(marketAddress).get();
    if (existing.exists) return; // Already flagged

    // Extract outcome token from instruction accounts
    const outcomeToken = instructionAccounts[3] || "";

    await db.collection("unmapped_markets").doc(marketAddress).set({
      jupiterAddress: marketAddress,
      outcomeToken,
      firstSeenAt: new Date(timestamp * 1000),
      betCount: 1,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info(`Flagged unmapped market: ${marketAddress}`);
  } catch (error) {
    logger.error(`Error flagging unmapped market ${marketAddress}:`, error);
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
 * Base58 decode helper
 */
function base58Decode(str: string): Uint8Array {
  const base58Chars = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
  let result = BigInt(0);
  for (let i = 0; i < str.length; i++) {
    result = result * BigInt(58) + BigInt(base58Chars.indexOf(str[i]));
  }
  const bytes: number[] = [];
  while (result > BigInt(0)) {
    bytes.unshift(Number(result % BigInt(256)));
    result = result / BigInt(256);
  }
  // Add leading zeros
  for (let i = 0; i < str.length && str[i] === "1"; i++) {
    bytes.unshift(0);
  }
  return new Uint8Array(bytes);
}

/**
 * Bet placement instruction discriminator
 */
const BET_PLACEMENT_DISCRIMINATOR = "8d3625cfedd2fad7";

/**
 * Extract price and amount from bet placement instruction data
 * Returns null if not a bet placement or can't decode
 */
function decodeBetInstruction(instructionData: string): {
  amount: number;
  price: number;
  shares: number;
} | null {
  try {
    const decoded = base58Decode(instructionData);
    const discriminator = Buffer.from(decoded.slice(0, 8)).toString("hex");

    // Only decode bet placements
    if (discriminator !== BET_PLACEMENT_DISCRIMINATOR) {
      return null;
    }

    // Need at least 16 bytes after discriminator for amount and price
    if (decoded.length < 24) {
      return null;
    }

    const view = new DataView(decoded.buffer, decoded.byteOffset);
    const len = decoded.length;

    // Last 8 bytes = amount in micro-USDC
    const amountRaw = Number(view.getBigUint64(len - 8, true));
    // Second-to-last 8 bytes = price in micro-dollars
    const priceRaw = Number(view.getBigUint64(len - 16, true));

    const amount = amountRaw / 1e6;
    const price = priceRaw / 1e6;

    // Sanity check
    if (price <= 0 || price > 1 || amount <= 0) {
      return null;
    }

    const shares = amount / price;

    return { amount, price, shares };
  } catch (error) {
    return null;
  }
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

    // Find USDC and outcome token transfers
    let usdcSpent = 0;
    let usdcReceived = 0;
    let sharesReceived = 0;

    // Debug: log transaction structure
    logger.info(`Parsing tx ${tx.signature.slice(0, 8)}: feePayer=${tx.feePayer.slice(0, 8)}, tokenTransfers=${tx.tokenTransfers?.length || 0}, accountData=${tx.accountData?.length || 0}`);

    // Method 1: Use tokenTransfers (Helius enhanced format - most reliable)
    for (const transfer of tx.tokenTransfers || []) {
      logger.debug(`Transfer: mint=${transfer.mint.slice(0, 8)}, amount=${transfer.tokenAmount}, from=${transfer.fromUserAccount?.slice(0, 8)}, to=${transfer.toUserAccount?.slice(0, 8)}`);

      // USDC transfer
      if (transfer.mint === USDC_MINT) {
        if (transfer.fromUserAccount === tx.feePayer) {
          usdcSpent += transfer.tokenAmount;
        }
        if (transfer.toUserAccount === tx.feePayer) {
          usdcReceived += transfer.tokenAmount;
        }
      }
      // Outcome token transfer (shares)
      if (transfer.mint === outcomeToken && transfer.toUserAccount === tx.feePayer) {
        sharesReceived += transfer.tokenAmount;
      }
    }

    // Method 2: Fallback to accountData.tokenBalanceChanges
    if (usdcSpent === 0 && usdcReceived === 0) {
      logger.info(`Using accountData fallback for tx ${tx.signature.slice(0, 8)}`);

      for (const account of tx.accountData || []) {
        for (const change of account.tokenBalanceChanges || []) {
          const amount = parseFloat(change.rawTokenAmount.tokenAmount);
          const decimals = change.rawTokenAmount.decimals;
          const value = amount / Math.pow(10, decimals);

          // Only count changes for the user's accounts (userAccount matches feePayer)
          const isUserAccount = change.userAccount === tx.feePayer;

          logger.debug(`Balance change: mint=${change.mint.slice(0, 8)}, value=${value}, userAccount=${change.userAccount?.slice(0, 8) || 'null'}, isUser=${isUserAccount}`);

          // For USDC, count user's spending (negative) and receiving (positive)
          if (change.mint === USDC_MINT && isUserAccount) {
            if (value < 0) {
              usdcSpent += Math.abs(value);
            } else if (value > 0) {
              usdcReceived += value;
            }
          }

          // For outcome tokens, look for user receiving shares (positive)
          if (change.mint === outcomeToken && isUserAccount && value > 0) {
            sharesReceived += value;
          }
        }
      }
    }

    // Net USDC change: negative means placing bet, positive means claiming
    const usdcChange = usdcReceived - usdcSpent;

    logger.info(`Parsed tx ${tx.signature.slice(0, 8)}: spent=${usdcSpent}, received=${usdcReceived}, netUSDC=${usdcChange}, shares=${sharesReceived}`);

    // Determine bet direction and type based on USDC flow
    // Spending USDC = placing a bet (buying shares)
    // Receiving USDC = claiming winnings or closing position
    const isPlacingBet = usdcSpent > usdcReceived;
    const amount = isPlacingBet ? usdcSpent : usdcReceived;

    // Skip if no meaningful amount
    if (amount === 0) {
      logger.warn(`No USDC movement found for tx ${tx.signature.slice(0, 8)}`);
      return null;
    }

    // Try to decode price directly from instruction data (most accurate)
    let avgPrice = 0.5; // Default fallback
    let sharesEstimated = false;
    const decodedBet = decodeBetInstruction(instruction.data);

    if (decodedBet) {
      // Got real price from instruction data
      avgPrice = decodedBet.price;
      sharesReceived = decodedBet.shares;
      logger.info(`Decoded bet from instruction: $${decodedBet.amount.toFixed(2)} at ${(decodedBet.price * 100).toFixed(2)}¢ = ${decodedBet.shares.toFixed(4)} shares`);
    } else if (sharesReceived > 0 && usdcSpent > 0) {
      // Calculate from token transfers
      avgPrice = usdcSpent / sharesReceived;
      if (avgPrice > 1) {
        logger.warn(`Unusual avgPrice ${avgPrice} for tx ${tx.signature.slice(0, 8)}, capping at 1`);
        avgPrice = Math.min(avgPrice, 1);
      }
    }

    // ALWAYS ensure shares > 0 for valid bets - estimate if needed
    // Use 0.5 as default price if avgPrice is 0 or invalid
    if (sharesReceived === 0 && amount > 0) {
      const priceToUse = avgPrice > 0 && avgPrice <= 1 ? avgPrice : 0.5;
      sharesReceived = amount / priceToUse;
      sharesEstimated = true;
      logger.info(`Estimated ${sharesReceived.toFixed(2)} shares for tx ${tx.signature.slice(0, 8)} (amount=${amount}, priceUsed=${priceToUse})`);
    }

    // Ensure avgPrice is valid for storage
    if (avgPrice <= 0 || avgPrice > 1) {
      avgPrice = 0.5;
    }

    // Determine YES/NO direction - MUST BE VERIFIED
    const directionResult = await determineDirection(outcomeToken, marketAddress);

    if (directionResult === null) {
      // Direction could not be verified - flag for manual review
      logger.error(`UNVERIFIED BET: ${tx.signature} - cannot determine direction for token ${outcomeToken}`);

      // Store in unverified_bets collection for later processing
      await db.collection("unverified_bets").doc(tx.signature).set({
        signature: tx.signature,
        walletAddress: tx.feePayer,
        marketAddress,
        outcomeToken,
        amount,
        shares: sharesReceived,
        avgPrice,
        timestamp: new Date(tx.timestamp * 1000),
        reason: "direction_unverified",
        createdAt: FieldValue.serverTimestamp(),
      });

      return null; // Do NOT store as a valid bet
    }

    logger.info(`Direction verified: ${directionResult.direction} (${directionResult.confidence}) via ${directionResult.source}`);

    return {
      walletAddress: tx.feePayer,
      signature: tx.signature,
      timestamp: new Date(tx.timestamp * 1000),
      marketAddress,
      direction: directionResult.direction,
      amount,
      shares: sharesReceived,
      avgPrice,
      sharesEstimated, // True if shares were estimated (minted tokens don't show in Helius)
      status: isPlacingBet ? "open" : "claimed",
      canCopy: isPlacingBet, // Only copy new bets
      verified: true, // This bet has verified direction
      confidence: directionResult.confidence, // high, medium, or low
    };
  } catch (error) {
    logger.error("Error parsing prediction bet:", error);
    return null;
  }
}

/**
 * Direction result with confidence level
 */
interface DirectionResult {
  direction: BetDirection;
  confidence: "high" | "medium" | "low";
  source: string;
}

/**
 * Determine if the outcome token is YES or NO
 * Uses VERIFIED on-chain data only - NO GUESSING
 * Returns null if direction cannot be verified
 */
async function determineDirection(
  outcomeToken: string,
  marketAddress: string
): Promise<DirectionResult | null> {
  // 1. Try market registry first (already verified)
  const mapping = await getMarketMapping(marketAddress);
  if (mapping && mapping.yesTokenMint && mapping.noTokenMint) {
    if (mapping.yesTokenMint === outcomeToken) {
      return { direction: "YES", confidence: "medium", source: "cached_registry" };
    }
    if (mapping.noTokenMint === outcomeToken) {
      return { direction: "NO", confidence: "medium", source: "cached_registry" };
    }
  }

  // 2. Try to find by token across all mappings
  const tokenMatch = await getMarketByToken(outcomeToken);
  if (tokenMatch) {
    return { direction: tokenMatch.direction, confidence: "medium", source: "token_lookup" };
  }

  // 3. Parse on-chain market account to get verified YES/NO tokens (HIGHEST CONFIDENCE)
  try {
    const apiKey = HELIUS_API_KEY.value();
    const marketAccount = await parseJupiterMarketAccount(marketAddress, apiKey);

    if (marketAccount && marketAccount.verified) {
      // Cache the verified tokens in the registry for future lookups
      await db.collection("market_mappings").doc(marketAddress).set({
        jupiterAddress: marketAddress,
        yesTokenMint: marketAccount.yesTokenMint,
        noTokenMint: marketAccount.noTokenMint,
        source: "on-chain-verified",
        verified: true,
        status: "active",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      logger.info(`Verified market ${marketAddress} on-chain: YES=${marketAccount.yesTokenMint}, NO=${marketAccount.noTokenMint}`);

      if (marketAccount.yesTokenMint === outcomeToken) {
        return { direction: "YES", confidence: "high", source: "on_chain_verified" };
      }
      if (marketAccount.noTokenMint === outcomeToken) {
        return { direction: "NO", confidence: "high", source: "on_chain_verified" };
      }
    }
  } catch (error) {
    logger.error(`Error parsing market account ${marketAddress}:`, error);
  }

  // 4. Check legacy cache (for backwards compatibility with verified data)
  const marketDoc = await db.collection("prediction_markets").doc(marketAddress).get();
  if (marketDoc.exists) {
    const data = marketDoc.data();
    if (data?.verified === true) {
      if (data?.yesToken === outcomeToken) {
        return { direction: "YES", confidence: "low", source: "legacy_cache" };
      }
      if (data?.noToken === outcomeToken) {
        return { direction: "NO", confidence: "low", source: "legacy_cache" };
      }
    }
  }

  // NO GUESSING - return null if we can't verify
  logger.error(`UNVERIFIED: Could not determine direction for token ${outcomeToken} in market ${marketAddress}`);
  return null;
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
