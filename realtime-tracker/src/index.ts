/**
 * Helius WebSocket Real-Time Smart Money Tracker
 *
 * FASTEST method - sub-second latency (~500-800ms from block to notification)
 *
 * Deploy: gcloud run deploy helius-realtime --source . --min-instances=1
 */

import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import WebSocket from "ws";
import http from "http";

// Initialize Firebase
if (!getApps().length) {
  initializeApp();
}
const db = getFirestore();

// Config
const HELIUS_API_KEY = process.env.HELIUS_API_KEY!;
const HELIUS_WS_URL = `wss://mainnet.helius-rpc.com/?api-key=${HELIUS_API_KEY}`;
const PORT = process.env.PORT || 8080;

// Jupiter Prediction Program
const JUPITER_PREDICTION_PROGRAM = "3ZZuTbwC6aJbvteyVxXUS7gtFYdf7AuXeitx6VyvjvUp";
const USDC_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v";

// Smart money wallets cache
let smartMoneyWallets = new Map<string, { nickname?: string; docId: string }>();

// Market metadata cache (in-memory for quick lookups)
let marketCache = new Map<string, { title: string; category: string; cachedAt: number }>();

// Jupiter Prediction API
const JUPITER_PREDICTION_API = "https://prediction-market-api.jup.ag/api/v1";

// Stats
let stats = {
  connected: false,
  lastMessage: 0,
  txProcessed: 0,
  betsFound: 0,
  marketsKnown: 0,
  startTime: Date.now(),
};

/**
 * Start the real-time tracker
 */
async function start() {
  console.log("🚀 Starting Helius Real-Time Smart Money Tracker");
  console.log(`   Program: ${JUPITER_PREDICTION_PROGRAM}`);

  // HTTP server for health checks and webhook
  const server = http.createServer(async (req, res) => {
    // CORS headers for browser access
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    // Handle preflight
    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    // Health check endpoint
    if ((req.url === "/health" || req.url === "/") && req.method === "GET") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({
        status: "ok",
        connected: stats.connected,
        uptime: Math.floor((Date.now() - stats.startTime) / 1000),
        txProcessed: stats.txProcessed,
        betsFound: stats.betsFound,
        walletsTracked: smartMoneyWallets.size,
        marketsKnown: marketCache.size,
        lastMessage: stats.lastMessage ? new Date(stats.lastMessage).toISOString() : null,
      }));
      return;
    }

    // Helius webhook endpoint
    if (req.url === "/webhook" && req.method === "POST") {
      try {
        const chunks: Buffer[] = [];
        for await (const chunk of req) {
          chunks.push(chunk as Buffer);
        }
        const body = Buffer.concat(chunks).toString();
        const data = JSON.parse(body);

        stats.lastMessage = Date.now();
        console.log(`📨 Webhook received: ${Array.isArray(data) ? data.length : 1} transaction(s)`);

        // Helius sends an array of transactions
        const transactions = Array.isArray(data) ? data : [data];

        for (const tx of transactions) {
          stats.txProcessed++;
          await processWebhookTransaction(tx);
        }

        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ success: true }));
      } catch (error) {
        console.error("Webhook error:", error);
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Internal error" }));
      }
      return;
    }

    res.writeHead(404);
    res.end();
  });

  await new Promise<void>((resolve) => {
    server.listen(PORT, () => {
      console.log(`✅ Health server listening on port ${PORT}`);
      resolve();
    });
  });

  // Now initialize Firebase and start tracking
  try {
    await refreshSmartMoneyWallets();
    await loadCachedMarkets(); // Load cached markets from Firestore (no API calls)

    // Try WebSocket but don't fail if it doesn't work - webhook is the backup
    try {
      connectWebSocket();
    } catch (wsError) {
      console.log("⚠️ WebSocket not available, using webhook only");
    }

    setInterval(refreshSmartMoneyWallets, 5 * 60 * 1000);
    // Removed expensive syncMarketMetadata interval - using cache only

    console.log("✅ Ready to receive webhook events at /webhook");
  } catch (error) {
    console.error("Failed to initialize tracking:", error);
    // Keep server running for health checks even if tracking fails
  }
}

/**
 * Connect to Helius WebSocket
 * DISABLED - WebSocket requires expensive Helius API calls per transaction
 * Using webhook only which receives pre-enriched data
 */
function connectWebSocket() {
  console.log("📡 WebSocket disabled to save costs - using webhook only");
  // WebSocket connection disabled to avoid expensive Helius API calls
  // The webhook at /webhook receives pre-enriched transaction data
}

/**
 * Process transaction (DISABLED - was used for WebSocket which is now disabled)
 * This function made expensive Helius API calls per transaction
 * Now using webhook only which receives pre-enriched data
 */
async function processTransaction(_signature: string) {
  // DISABLED - WebSocket processing disabled to save costs
  // Use processWebhookTransaction via the /webhook endpoint instead
  return;
}

/**
 * Process transaction from Helius webhook
 * Webhook data is already in enhanced format
 */
async function processWebhookTransaction(tx: any) {
  const startTime = Date.now();

  try {
    // Check if smart money
    const walletInfo = smartMoneyWallets.get(tx.feePayer);
    if (!walletInfo) return;

    console.log(`   Processing tx from ${walletInfo.nickname || tx.feePayer.slice(0, 8)}...`);

    // Parse bet from the enhanced transaction data
    const bet = parseBet(tx);
    if (!bet || bet.amount === 0) return;

    bet.walletNickname = walletInfo.nickname;

    // Get market info from cache only (no expensive API calls)
    const market = await getMarketInfo(bet.marketAddress);
    if (market) {
      bet.marketTitle = market.title;
      bet.marketCategory = market.category;
    }

    // Use parsed transaction data directly (no expensive Jupiter API calls)
    // Final sanity check
    if (bet.avgPrice === 0 && bet.amount > 0 && bet.shares > 0) {
      bet.avgPrice = bet.amount / bet.shares;
    }

    console.log(`   Final bet: ${bet.direction} $${bet.amount.toFixed(2)} @ ${(bet.avgPrice * 100).toFixed(0)}¢`);

    // Save to Firestore
    await db.collection("prediction_bets").doc(tx.signature).set({
      ...bet,
      source: "helius_webhook",
      latencyMs: Date.now() - startTime,
      createdAt: FieldValue.serverTimestamp(),
    });

    stats.betsFound++;

    // Send push notification
    await sendNotification(bet);

    // Trigger auto-copy
    triggerAutoCopy(bet, tx.signature).catch((err) => {
      console.error("Auto-copy trigger error:", err);
    });

    console.log(
      `⚡ [${Date.now() - startTime}ms] ${walletInfo.nickname || tx.feePayer.slice(0, 8)}... ` +
      `${bet.direction} $${bet.amount.toFixed(2)} "${bet.marketTitle || ""}"`
    );

  } catch (error) {
    console.error("processWebhookTransaction error:", error);
  }
}

/**
 * Parse bet from transaction
 */
function parseBet(tx: any): any | null {
  const ix = tx.instructions?.find((i: any) => i.programId === JUPITER_PREDICTION_PROGRAM);
  if (!ix) return null;

  let usdcChange = 0;
  let shares = 0;
  const outcomeToken = ix.accounts[3];

  // Track all token changes to help determine direction
  const tokenChanges: { mint: string; amount: number }[] = [];

  for (const acc of tx.accountData || []) {
    for (const change of acc.tokenBalanceChanges || []) {
      if (change.mint === USDC_MINT && change.userAccount === tx.feePayer) {
        usdcChange = parseFloat(change.rawTokenAmount.tokenAmount) / 1e6;
      }
      if (change.userAccount === tx.feePayer && change.mint !== USDC_MINT) {
        const tokenAmount = parseFloat(change.rawTokenAmount.tokenAmount) / 1e6;
        tokenChanges.push({ mint: change.mint, amount: tokenAmount });
        if (change.mint === outcomeToken) {
          shares = Math.abs(tokenAmount);
        }
      }
    }
  }

  // If no shares found from outcomeToken match, use the largest non-USDC token change
  // This handles cases where the outcome token account index varies
  if (shares === 0 && tokenChanges.length > 0) {
    const largestChange = tokenChanges.reduce((max, tc) =>
      Math.abs(tc.amount) > Math.abs(max.amount) ? tc : max
    );
    shares = Math.abs(largestChange.amount);
  }

  const isBuy = usdcChange < 0;
  const amount = Math.abs(usdcChange);

  // Determine direction from the token received
  // The direction is determined by which outcome token the user receives
  // We need to check the actual token mint against known patterns or use API lookup later
  let direction: "YES" | "NO" | null = null;
  let receivedTokenMint: string | null = null;

  // Find which non-USDC token the user received (positive balance change = received)
  for (const change of tokenChanges) {
    if (change.amount > 0) {
      receivedTokenMint = change.mint;
      break;
    }
  }

  // Log token changes for debugging
  if (tokenChanges.length > 0) {
    console.log(`   Token changes: ${tokenChanges.map(t => `${t.mint.slice(0,8)}:${t.amount > 0 ? '+' : ''}${t.amount.toFixed(2)}`).join(', ')}`);
  }

  // Calculate avgPrice from amount and shares
  let avgPrice = 0;
  if (shares > 0 && amount > 0) {
    avgPrice = amount / shares;
    // Sanity check: price should be between 0.01 and 0.99
    if (avgPrice < 0.01 || avgPrice > 0.99) {
      console.log(`   ⚠️ Unusual avgPrice: ${avgPrice.toFixed(4)} (amount=${amount}, shares=${shares})`);
      avgPrice = 0; // Mark as needing API lookup
    }
  }

  return {
    walletAddress: tx.feePayer,
    signature: tx.signature,
    timestamp: new Date(tx.timestamp * 1000),
    marketAddress: ix.accounts[1],
    direction: direction || "YES", // Default YES, will be corrected by API lookup
    amount,
    shares,
    avgPrice,
    receivedTokenMint, // Store for potential future matching
    status: isBuy ? "open" : "claimed",
    canCopy: isBuy,
  };
}

/**
 * Get market info from cache only (no expensive API calls)
 */
async function getMarketInfo(address: string): Promise<any | null> {
  try {
    // Check in-memory cache first (fastest)
    const memCached = marketCache.get(address);
    if (memCached) {
      return memCached;
    }

    // Check Firestore cache
    const cached = await db.collection("prediction_markets").doc(address).get();
    if (cached.exists) {
      const data = cached.data();
      if (data?.title) {
        marketCache.set(address, {
          title: data.title,
          category: data.category || "Unknown",
          cachedAt: Date.now(),
        });
        return data;
      }
    }

    // No expensive API fallbacks - return null if not cached
    return null;
  } catch (error) {
    console.error(`Failed to get market info for ${address}:`, error);
    return null;
  }
}

/**
 * Load cached markets from Firestore into memory (no API calls)
 */
async function loadCachedMarkets() {
  console.log("📋 Loading cached markets from Firestore...");

  try {
    const existingMarkets = await db.collection("prediction_markets").limit(200).get();
    existingMarkets.docs.forEach((doc) => {
      const data = doc.data();
      if (data.title) {
        marketCache.set(doc.id, {
          title: data.title,
          category: data.category || "Unknown",
          cachedAt: Date.now(),
        });
      }
    });

    stats.marketsKnown = marketCache.size;
    console.log(`✅ Loaded ${marketCache.size} markets from cache`);
  } catch (error) {
    console.error("Failed to load cached markets:", error);
  }
}

/**
 * Refresh smart money wallets
 */
async function refreshSmartMoneyWallets() {
  const snapshot = await db.collection("smart_money_wallets")
    .where("isActive", "==", true)
    .get();

  smartMoneyWallets.clear();
  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    smartMoneyWallets.set(data.address, { nickname: data.nickname, docId: doc.id });
  });

  console.log(`📋 Tracking ${smartMoneyWallets.size} wallets`);
}

/**
 * Send push notification
 */
async function sendNotification(bet: any) {
  try {
    const users = await db.collection("users")
      .where("notificationsEnabled", "==", true)
      .get();

    const tokens: string[] = [];
    users.docs.forEach((doc) => {
      const data = doc.data();
      if (data.fcmTokens?.length) tokens.push(...data.fcmTokens);
    });

    if (!tokens.length) return;

    const name = bet.walletNickname || bet.walletAddress.slice(0, 8) + "...";

    for (let i = 0; i < tokens.length; i += 500) {
      await getMessaging().sendEachForMulticast({
        tokens: tokens.slice(i, i + 500),
        notification: {
          title: `⚡ ${name} placed a bet`,
          body: `${bet.direction} on "${bet.marketTitle || "market"}" - $${bet.amount.toFixed(2)}`,
        },
        data: { type: "smart_money_bet", signature: bet.signature },
        apns: { payload: { aps: { sound: "default" } } },
      });
    }
  } catch (error) {
    console.error("Notification error:", error);
  }
}

/**
 * Trigger auto-copy for users following this wallet
 * Creates pending copy trades and either:
 * - Auto-executes via Cloud Function (if user has delegation)
 * - Sends notification for manual execution (if no delegation)
 *
 * Optimized: Batch fetches user documents to reduce N+1 DB calls
 */
async function triggerAutoCopy(bet: any, betId: string) {
  try {
    // Only trigger for buy bets (canCopy = true)
    if (!bet.canCopy || bet.amount <= 0) {
      return;
    }

    // Find users tracking this wallet with auto-copy enabled
    const trackersSnapshot = await db.collection("tracked_predictors")
      .where("walletAddress", "==", bet.walletAddress)
      .where("autoCopyEnabled", "==", true)
      .get();

    if (trackersSnapshot.empty) {
      return;
    }

    console.log(`🎯 Auto-copy: ${trackersSnapshot.size} users tracking ${bet.walletAddress.slice(0, 8)}...`);

    // Batch fetch all user documents upfront to avoid N+1 queries
    const userIds = [...new Set(trackersSnapshot.docs.map((d) => d.data().userId))];
    const userRefs = userIds.map((id) => db.collection("users").doc(id));
    const userDocs = await db.getAll(...userRefs);

    // Build userId -> userData map for O(1) lookups
    const userDataMap = new Map<string, FirebaseFirestore.DocumentData>();
    userDocs.forEach((doc) => {
      if (doc.exists) {
        userDataMap.set(doc.id, doc.data()!);
      }
    });

    for (const trackerDoc of trackersSnapshot.docs) {
      const tracker = trackerDoc.data();
      const userId = tracker.userId;

      try {
        // Get user data from pre-fetched map
        const userData = userDataMap.get(userId);

        if (!userData?.walletAddress) {
          continue;
        }

        // Get copy settings
        const copyPercentage = tracker.copyPercentage || 5;
        const maxCopyAmountUsd = tracker.maxCopyAmountUsd || 50;
        const minBetSizeUsd = tracker.minBetSizeUsd || 5;

        // Skip small bets
        if (bet.amount < minBetSizeUsd) {
          console.log(`⏭️ Skipping small bet ($${bet.amount}) for ${userId}`);
          continue;
        }

        // Calculate suggested amount
        let suggestedAmount = Math.min(
          bet.amount * (copyPercentage / 100),
          maxCopyAmountUsd
        );
        suggestedAmount = Math.max(suggestedAmount, minBetSizeUsd);

        // Create pending copy trade
        const pendingRef = db.collection("pending_copy_trades").doc();
        const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 min window

        await pendingRef.set({
          id: pendingRef.id,
          userId,
          userWalletAddress: userData.walletAddress,
          betId,
          trackedWallet: bet.walletAddress,
          trackedWalletNickname: tracker.nickname || bet.walletNickname,
          marketAddress: bet.marketAddress,
          marketTitle: bet.marketTitle,
          direction: bet.direction,
          originalAmount: bet.amount,
          originalPrice: bet.avgPrice,
          suggestedAmount,
          status: "pending",
          createdAt: FieldValue.serverTimestamp(),
          expiresAt,
          originalSignature: betId, // Store for transaction rebuilding
        });

        console.log(`✅ Created pending copy for ${userId}: $${suggestedAmount.toFixed(2)} ${bet.direction}`);

        // Check if user has delegation enabled for auto-execution
        const hasDelegation = userData.predictionDelegationActive === true;

        if (hasDelegation) {
          // Trigger server-side execution via Cloud Function
          console.log(`🤖 User ${userId} has delegation - triggering auto-execution`);

          try {
            await triggerServerSideExecution(pendingRef.id, userId);
            console.log(`✅ Auto-execution triggered for ${userId}`);

            // Send success notification
            const fcmTokens = userData.fcmTokens || [];
            if (fcmTokens.length > 0) {
              const nickname = tracker.nickname || bet.walletNickname || bet.walletAddress.slice(0, 8) + "...";
              await getMessaging().sendEachForMulticast({
                tokens: fcmTokens,
                notification: {
                  title: `✅ Copy Trade Executed`,
                  body: `Auto-copied ${nickname}'s ${bet.direction} bet for $${suggestedAmount.toFixed(2)}`,
                },
                data: {
                  type: "prediction_copy_executed",
                  pendingCopyId: pendingRef.id,
                  marketAddress: bet.marketAddress,
                  direction: bet.direction,
                  amount: suggestedAmount.toString(),
                },
                apns: {
                  payload: { aps: { sound: "default" } },
                },
              });
            }

            continue; // Skip manual notification flow
          } catch (execError) {
            console.error(`Auto-execution failed for ${userId}:`, execError);
            // Fall through to manual notification flow
          }
        }

        // Manual flow: Send actionable push notification
        const fcmTokens = userData.fcmTokens || [];
        if (fcmTokens.length > 0) {
          const nickname = tracker.nickname || bet.walletNickname || bet.walletAddress.slice(0, 8) + "...";
          const title = `🎯 Copy Trade Ready`;
          const body = `${nickname} bet ${bet.direction} on "${bet.marketTitle || "market"}". Tap to copy $${suggestedAmount.toFixed(2)}`;

          await getMessaging().sendEachForMulticast({
            tokens: fcmTokens,
            notification: { title, body },
            data: {
              type: "prediction_copy_ready",
              pendingCopyId: pendingRef.id,
              marketAddress: bet.marketAddress,
              direction: bet.direction,
              amount: suggestedAmount.toString(),
              jupiterUrl: `https://jup.ag/prediction/${bet.marketAddress}`,
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                  "content-available": 1,
                },
              },
            },
          });

          console.log(`📱 Sent copy notification to ${userId}`);
        }

        // Store in user's notifications
        await db.collection("users").doc(userId).collection("notifications").add({
          type: "prediction_copy_ready",
          title: "Copy Trade Available",
          body: `${tracker.nickname || bet.walletAddress.slice(0, 8)}... bet ${bet.direction}`,
          pendingCopyId: pendingRef.id,
          marketAddress: bet.marketAddress,
          marketTitle: bet.marketTitle,
          direction: bet.direction,
          suggestedAmount,
          trackedWallet: bet.walletAddress,
          createdAt: FieldValue.serverTimestamp(),
          read: false,
          expiresAt,
        });

      } catch (err) {
        console.error(`Auto-copy error for user ${userId}:`, err);
      }
    }

  } catch (error) {
    console.error("triggerAutoCopy error:", error);
  }
}

/**
 * Trigger server-side copy execution via Cloud Function
 * Called for users with active prediction delegation
 */
async function triggerServerSideExecution(pendingCopyId: string, userId: string) {
  const projectId = process.env.GCLOUD_PROJECT || "mimic-442700";
  const region = "us-central1";
  const functionName = "executePredictionCopyServer";

  // Get a service account token to call the Cloud Function
  // The Cloud Run service has the same service account, so we can use the metadata server
  const tokenResponse = await fetch(
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
    { headers: { "Metadata-Flavor": "Google" } }
  );
  const tokenData = await tokenResponse.json() as { access_token: string };
  const accessToken = tokenData.access_token;

  // Call the Cloud Function
  const functionUrl = `https://${region}-${projectId}.cloudfunctions.net/${functionName}`;

  const response = await fetch(functionUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      data: { pendingCopyId },
      // Simulate authenticated request with userId
      auth: { uid: userId },
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Cloud Function error: ${error}`);
  }

  const result = await response.json() as { result?: { success: boolean; message?: string } };

  if (!result.result?.success) {
    throw new Error(result.result?.message || "Execution failed");
  }

  return result.result;
}

// Start
start().catch(console.error);
