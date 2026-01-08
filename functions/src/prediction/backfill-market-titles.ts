/**
 * Backfill market titles for bets that don't have them
 * Uses Jupiter positions API to match bets to markets
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

const db = getFirestore();
const JUPITER_PREDICTION_API = "https://prediction-market-api.jup.ag/api/v1";

interface Position {
  marketId: string;
  eventMetadata?: {
    title?: string;
    category?: string;
  };
  marketMetadata?: {
    title?: string;
  };
}

/**
 * Backfill market titles for existing bets - admin only
 */
export const backfillMarketTitles = onCall(
  {
    timeoutSeconds: 540,
    cors: true,
  },
  async (request) => {
    // Admin check
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.data()?.email !== "malik@stack-labs.net") {
      throw new HttpsError("permission-denied", "Admin access required");
    }

    logger.info("Starting market title backfill...");

    try {
      // Get all bets without market titles
      const betsSnapshot = await db
        .collection("prediction_bets")
        .where("marketTitle", "==", null)
        .limit(200)
        .get();

      logger.info(`Found ${betsSnapshot.size} bets without market titles`);

      if (betsSnapshot.empty) {
        // Also try fetching bets where marketTitle doesn't exist
        const betsSnapshot2 = await db
          .collection("prediction_bets")
          .limit(200)
          .get();

        const betsWithoutTitles = betsSnapshot2.docs.filter(
          doc => !doc.data().marketTitle
        );

        logger.info(`Found ${betsWithoutTitles.length} bets without titles (second pass)`);

        if (betsWithoutTitles.length === 0) {
          return { success: true, updated: 0, message: "No bets need updating" };
        }
      }

      // Group bets by wallet address
      const betsByWallet = new Map<string, Array<{ id: string; data: any }>>();

      const docsToProcess = betsSnapshot.empty
        ? (await db.collection("prediction_bets").limit(200).get()).docs.filter(d => !d.data().marketTitle)
        : betsSnapshot.docs;

      for (const doc of docsToProcess) {
        const data = doc.data();
        if (!data.marketTitle) {
          const wallet = data.walletAddress;
          if (!betsByWallet.has(wallet)) {
            betsByWallet.set(wallet, []);
          }
          betsByWallet.get(wallet)!.push({ id: doc.id, data });
        }
      }

      logger.info(`Processing bets for ${betsByWallet.size} wallets`);

      let updated = 0;
      let failed = 0;

      // Process each wallet's bets
      for (const [walletAddress, bets] of betsByWallet) {
        try {
          // Fetch wallet's positions from Jupiter API
          const positions = await fetchWalletPositions(walletAddress);
          logger.info(`Wallet ${walletAddress.slice(0, 8)}... has ${positions.length} positions`);

          // Build a map of market info from positions
          const marketInfoMap = new Map<string, { title: string; category: string }>();

          for (const pos of positions) {
            if (pos.eventMetadata?.title) {
              const title = pos.marketMetadata?.title
                ? `${pos.eventMetadata.title} - ${pos.marketMetadata.title}`
                : pos.eventMetadata.title;

              marketInfoMap.set(pos.marketId, {
                title,
                category: pos.eventMetadata.category || "Unknown",
              });
            }
          }

          // If we have positions, use the most recent one's market for bets
          if (positions.length > 0 && positions[0].eventMetadata?.title) {
            const defaultMarket = positions[0];
            const defaultTitle = defaultMarket.marketMetadata?.title
              ? `${defaultMarket.eventMetadata!.title} - ${defaultMarket.marketMetadata.title}`
              : defaultMarket.eventMetadata!.title;

            // Update each bet that doesn't have a title
            for (const bet of bets) {
              // Try to match by marketAddress first
              let marketInfo = marketInfoMap.get(bet.data.marketAddress);

              // If no direct match, use position data
              if (!marketInfo && positions.length > 0) {
                // Find closest position by timestamp
                const betTime = bet.data.timestamp?.toDate?.() || new Date(bet.data.timestamp);
                let closestPos = positions[0];
                let closestDiff = Infinity;

                for (const pos of positions) {
                  // If position has creation time, use it
                  const posDiff = Math.abs(Date.now() - betTime.getTime());
                  if (posDiff < closestDiff) {
                    closestDiff = posDiff;
                    closestPos = pos;
                  }
                }

                if (closestPos.eventMetadata?.title) {
                  marketInfo = {
                    title: closestPos.marketMetadata?.title
                      ? `${closestPos.eventMetadata.title} - ${closestPos.marketMetadata.title}`
                      : closestPos.eventMetadata.title,
                    category: closestPos.eventMetadata.category || "Unknown",
                  };
                }
              }

              if (marketInfo) {
                await db.collection("prediction_bets").doc(bet.id).update({
                  marketTitle: marketInfo.title,
                  marketCategory: marketInfo.category,
                  backfilledTitle: true,
                  titleBackfilledAt: FieldValue.serverTimestamp(),
                });
                updated++;
                logger.info(`Updated bet ${bet.id.slice(0, 8)}... with title: ${marketInfo.title}`);
              } else {
                failed++;
              }
            }
          } else {
            // No positions found, try fetching from active events
            const eventMarkets = await fetchActiveEventMarkets();

            for (const bet of bets) {
              const marketInfo = eventMarkets.get(bet.data.marketAddress);
              if (marketInfo) {
                await db.collection("prediction_bets").doc(bet.id).update({
                  marketTitle: marketInfo.title,
                  marketCategory: marketInfo.category,
                  backfilledTitle: true,
                  titleBackfilledAt: FieldValue.serverTimestamp(),
                });
                updated++;
              } else {
                failed++;
              }
            }
          }

          // Rate limit
          await new Promise(resolve => setTimeout(resolve, 300));
        } catch (error) {
          logger.error(`Error processing wallet ${walletAddress}:`, error);
          failed += bets.length;
        }
      }

      logger.info(`Backfill complete: ${updated} updated, ${failed} failed`);

      return {
        success: true,
        updated,
        failed,
        totalProcessed: updated + failed,
      };
    } catch (error) {
      logger.error("Backfill error:", error);
      throw new HttpsError("internal", "Backfill failed");
    }
  }
);

/**
 * Fetch wallet positions from Jupiter API
 */
async function fetchWalletPositions(walletAddress: string): Promise<Position[]> {
  try {
    const res = await fetch(
      `${JUPITER_PREDICTION_API}/positions?ownerPubkey=${walletAddress}&limit=50`
    );

    if (!res.ok) {
      logger.warn(`Jupiter API returned ${res.status} for wallet ${walletAddress}`);
      return [];
    }

    const data = await res.json() as any;
    return data.data || [];
  } catch (error) {
    logger.error(`Error fetching positions for ${walletAddress}:`, error);
    return [];
  }
}

/**
 * Fetch active event markets to build a lookup map
 */
async function fetchActiveEventMarkets(): Promise<Map<string, { title: string; category: string }>> {
  const marketMap = new Map<string, { title: string; category: string }>();

  try {
    const res = await fetch(`${JUPITER_PREDICTION_API}/events?status=active&limit=50`);
    if (!res.ok) return marketMap;

    const data = await res.json() as any;
    const events = data.data || [];

    for (const event of events) {
      const eventTitle = event.metadata?.title || event.eventId;
      const category = event.category || "Unknown";

      for (const market of event.markets || []) {
        const fullTitle = market.metadata?.title
          ? `${eventTitle} - ${market.metadata.title}`
          : eventTitle;

        marketMap.set(market.marketId, { title: fullTitle, category });
      }
    }
  } catch (error) {
    logger.error("Error fetching active events:", error);
  }

  return marketMap;
}
