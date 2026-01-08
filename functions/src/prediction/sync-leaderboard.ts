/**
 * Sync top performers from Jupiter Prediction leaderboard
 * Runs daily to auto-discover and add smart money wallets
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { defineSecret } from "firebase-functions/params";
import { retryWithBackoff } from "../utils/solana-utils";

const db = getFirestore();
const HELIUS_API_KEY = defineSecret("HELIUS_API_KEY");

const JUPITER_LEADERBOARD_API = "https://prediction-market-api.jup.ag/api/v1/leaderboards";
const HELIUS_WEBHOOK_URL = "https://predictionwebhook-iiduicdzpq-uc.a.run.app";

interface LeaderboardTrader {
  ownerPubkey: string;
  realizedPnlUsd: string; // micro-USD (divide by 1,000,000)
  totalVolumeUsd: string;
  predictionsCount: number;
  correctPredictions: number;
  wrongPredictions: number;
  winRatePct: number;
}

interface LeaderboardResponse {
  data: LeaderboardTrader[];
}

/**
 * Scheduled function to sync Jupiter Prediction leaderboard daily
 */
export const syncLeaderboard = onSchedule(
  {
    schedule: "every day 00:00",
    timeZone: "America/New_York",
    secrets: [HELIUS_API_KEY],
    retryCount: 3,
  },
  async () => {
    await runLeaderboardSync(HELIUS_API_KEY.value());
  }
);

/**
 * Manual trigger for testing - admin only
 */
export const syncLeaderboardNow = onCall(
  {
    secrets: [HELIUS_API_KEY],
    cors: true,
  },
  async (request) => {
    // Admin check
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.data()?.isAdmin !== true) {
      throw new HttpsError("permission-denied", "Admin access required");
    }

    const result = await runLeaderboardSync(HELIUS_API_KEY.value());
    return result;
  }
);

/**
 * Core sync logic - shared by scheduled and manual triggers
 */
async function runLeaderboardSync(heliusApiKey: string): Promise<{
  success: boolean;
  added: number;
  updated: number;
  skipped: number;
}> {
  logger.info("Starting Jupiter Prediction leaderboard sync...");

  try {
    // Fetch top 50 by PnL (most profitable traders)
    const topByPnl = await fetchLeaderboard("all_time", "pnl", 50);
    logger.info(`Fetched ${topByPnl.length} traders by PnL`);

    // Fetch top 50 by win rate (most accurate traders)
    const topByWinRate = await fetchLeaderboard("all_time", "win_rate", 50);
    logger.info(`Fetched ${topByWinRate.length} traders by win rate`);

    // Combine and dedupe
    const allTraders = new Map<string, LeaderboardTrader>();
    for (const trader of [...topByPnl, ...topByWinRate]) {
      if (!allTraders.has(trader.ownerPubkey)) {
        allTraders.set(trader.ownerPubkey, trader);
      }
    }

    logger.info(`Found ${allTraders.size} unique top traders`);

    let added = 0;
    let updated = 0;
    let skipped = 0;

    for (const [address, trader] of allTraders) {
      // Skip if win rate < 50% or less than 10 bets
      if (trader.winRatePct < 50 || trader.predictionsCount < 10) {
        skipped++;
        continue;
      }

      const pnlUsd = parseInt(trader.realizedPnlUsd) / 1_000_000;
      const volumeUsd = parseInt(trader.totalVolumeUsd) / 1_000_000;

      // Check if already exists
      const existing = await db
        .collection("smart_money_wallets")
        .where("address", "==", address)
        .get();

      if (existing.empty) {
        // Add new wallet
        await db.collection("smart_money_wallets").add({
          address,
          nickname: `Top ${trader.winRatePct.toFixed(0)}%`,
          notes: `Auto-discovered. PnL: $${pnlUsd.toFixed(0)}`,
          stats: {
            totalBets: trader.predictionsCount,
            winRate: trader.winRatePct / 100,
            totalPnl: pnlUsd,
            avgBetSize: volumeUsd / trader.predictionsCount,
            wins: trader.correctPredictions,
            losses: trader.wrongPredictions,
          },
          addedAt: FieldValue.serverTimestamp(),
          addedBy: "leaderboard-sync",
          isActive: true,
          source: "jupiter_leaderboard",
        });

        // Add to Helius webhook for real-time tracking
        try {
          await addToHeliusWebhook(address, heliusApiKey);
        } catch (webhookError) {
          logger.error(`Failed to add ${address} to Helius webhook:`, webhookError);
        }

        added++;
        logger.info(`Added new smart money wallet: ${address.slice(0, 8)}... (${trader.winRatePct.toFixed(1)}% win rate)`);
      } else {
        // Update existing stats from leaderboard
        const doc = existing.docs[0];
        await doc.ref.update({
          "stats.totalBets": trader.predictionsCount,
          "stats.winRate": trader.winRatePct / 100,
          "stats.totalPnl": pnlUsd,
          "stats.wins": trader.correctPredictions,
          "stats.losses": trader.wrongPredictions,
          "stats.lastSyncedAt": FieldValue.serverTimestamp(),
        });
        updated++;
      }
    }

    logger.info(`Leaderboard sync complete: ${added} added, ${updated} updated, ${skipped} skipped`);

    return { success: true, added, updated, skipped };
  } catch (error) {
    logger.error("Error syncing leaderboard:", error);
    throw error;
  }
}

/**
 * Fetch leaderboard data from Jupiter API
 * Includes retry logic for transient failures
 */
async function fetchLeaderboard(
  period: string,
  metric: string,
  limit: number
): Promise<LeaderboardTrader[]> {
  const url = `${JUPITER_LEADERBOARD_API}?period=${period}&metric=${metric}&limit=${limit}`;

  return retryWithBackoff(async () => {
    const response = await fetch(url);

    if (!response.ok) {
      throw new Error(`Jupiter leaderboard API error: ${response.status} ${response.statusText}`);
    }

    const data = (await response.json()) as LeaderboardResponse;
    return data.data || [];
  }, 3, 1000); // 3 retries with 1s base delay
}

/**
 * Add wallet to Helius webhook for real-time transaction monitoring
 */
async function addToHeliusWebhook(address: string, apiKey: string): Promise<void> {
  // Get existing webhooks
  const webhooksResponse = await fetch(
    `https://api.helius.xyz/v0/webhooks?api-key=${apiKey}`
  );

  if (!webhooksResponse.ok) {
    throw new Error(`Helius API error: ${webhooksResponse.status}`);
  }

  const webhooks = await webhooksResponse.json();

  // Find our prediction webhook
  const predictionWebhook = webhooks.find(
    (w: { webhookURL: string }) => w.webhookURL === HELIUS_WEBHOOK_URL
  );

  if (predictionWebhook) {
    // Add address to existing webhook
    const currentAddresses = predictionWebhook.accountAddresses || [];
    if (!currentAddresses.includes(address)) {
      const updateResponse = await fetch(
        `https://api.helius.xyz/v0/webhooks/${predictionWebhook.webhookID}?api-key=${apiKey}`,
        {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            webhookURL: HELIUS_WEBHOOK_URL,
            accountAddresses: [...currentAddresses, address],
            transactionTypes: ["ANY"],
            webhookType: "enhanced",
          }),
        }
      );

      if (!updateResponse.ok) {
        throw new Error(`Failed to update Helius webhook: ${updateResponse.status}`);
      }
    }
  } else {
    // Create new webhook with this address
    const createResponse = await fetch(
      `https://api.helius.xyz/v0/webhooks?api-key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          webhookURL: HELIUS_WEBHOOK_URL,
          accountAddresses: [address],
          transactionTypes: ["ANY"],
          webhookType: "enhanced",
        }),
      }
    );

    if (!createResponse.ok) {
      throw new Error(`Failed to create Helius webhook: ${createResponse.status}`);
    }
  }
}
