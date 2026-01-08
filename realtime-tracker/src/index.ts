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

  // Health check server FIRST (required for Cloud Run)
  const server = http.createServer((req, res) => {
    // CORS headers for browser access
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    // Handle preflight
    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    if (req.url === "/health" || req.url === "/") {
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
    } else {
      res.writeHead(404);
      res.end();
    }
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
    await syncMarketMetadata(); // Initial sync of market metadata
    connectWebSocket();
    setInterval(refreshSmartMoneyWallets, 5 * 60 * 1000);
    setInterval(syncMarketMetadata, 10 * 60 * 1000); // Sync markets every 10 min
  } catch (error) {
    console.error("Failed to initialize tracking:", error);
    // Keep server running for health checks even if tracking fails
  }
}

/**
 * Connect to Helius WebSocket
 */
function connectWebSocket() {
  console.log("📡 Connecting to Helius WebSocket...");

  const ws = new WebSocket(HELIUS_WS_URL);

  ws.on("open", () => {
    stats.connected = true;
    console.log("✅ Connected to Helius WebSocket");

    // Subscribe to Jupiter Prediction Program
    ws.send(JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "logsSubscribe",
      params: [
        { mentions: [JUPITER_PREDICTION_PROGRAM] },
        { commitment: "confirmed" }
      ]
    }));
  });

  ws.on("message", async (data) => {
    stats.lastMessage = Date.now();

    try {
      const msg = JSON.parse(data.toString());

      if (msg.result !== undefined) {
        console.log(`✅ Subscribed (ID: ${msg.result})`);
        return;
      }

      if (msg.method === "logsNotification") {
        const signature = msg.params.result.value.signature;
        stats.txProcessed++;
        await processTransaction(signature);
      }
    } catch (error) {
      console.error("Message error:", error);
    }
  });

  ws.on("error", (error) => {
    console.error("WebSocket error:", error);
    stats.connected = false;
  });

  ws.on("close", () => {
    stats.connected = false;
    console.log("⚠️ WebSocket closed, reconnecting in 3s...");
    setTimeout(connectWebSocket, 3000);
  });

  // Ping every 30s to keep alive
  setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.ping();
    }
  }, 30000);
}

/**
 * Process transaction
 */
async function processTransaction(signature: string) {
  const startTime = Date.now();

  try {
    // Fetch enhanced transaction
    const response = await fetch(
      `https://api.helius.xyz/v0/transactions/?api-key=${HELIUS_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ transactions: [signature] }),
      }
    );

    const txData = await response.json() as any[];
    const tx = txData[0];
    if (!tx) return;

    // Check if smart money
    const walletInfo = smartMoneyWallets.get(tx.feePayer);
    if (!walletInfo) return;

    // Parse bet
    const bet = parseBet(tx);
    if (!bet || bet.amount === 0) return;

    bet.walletNickname = walletInfo.nickname;

    // Get market info (pass wallet to look up positions if needed)
    const market = await getMarketInfo(bet.marketAddress, bet.walletAddress);
    if (market) {
      bet.marketTitle = market.title;
      bet.marketCategory = market.category;
    }

    // Try to get accurate direction and price from wallet's positions
    try {
      const positionData = await fetchWalletPosition(bet.walletAddress, bet.marketAddress);
      if (positionData) {
        bet.direction = positionData.side || bet.direction;
        if (positionData.avgPrice > 0) {
          bet.avgPrice = positionData.avgPrice;
        }
        if (positionData.shares > 0) {
          bet.shares = positionData.shares;
        }
      }
    } catch {
      // Use parsed values if position lookup fails
    }

    // Save to Firestore
    await db.collection("prediction_bets").doc(signature).set({
      ...bet,
      source: "realtime_websocket",
      latencyMs: Date.now() - startTime,
      createdAt: FieldValue.serverTimestamp(),
    });

    stats.betsFound++;

    // Send push notification to all users
    await sendNotification(bet);

    // Trigger auto-copy for users following this wallet
    triggerAutoCopy(bet, signature).catch((err) => {
      console.error("Auto-copy trigger error:", err);
    });

    console.log(
      `⚡ [${Date.now() - startTime}ms] ${walletInfo.nickname || tx.feePayer.slice(0, 8)}... ` +
      `${bet.direction} $${bet.amount.toFixed(2)} "${bet.marketTitle || ""}"`
    );

  } catch (error) {
    // Silently ignore - not all program txs are bets
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

  const isBuy = usdcChange < 0;
  const amount = Math.abs(usdcChange);

  // Determine direction from instruction data
  // Jupiter Prediction uses instruction data where byte pattern indicates YES(0) or NO(1)
  let direction: "YES" | "NO" = "YES";

  if (ix.data) {
    // Try to parse instruction data - format varies but often has direction indicator
    // Check common patterns: base58 decoded first byte after discriminator
    try {
      // The instruction data often encodes direction in the parameters
      // Account ordering: YES token is typically accounts[2], NO token is accounts[3]
      // If the user received tokens from accounts[3], it's likely a NO bet
      const yesTokenAccount = ix.accounts[2];
      const noTokenAccount = ix.accounts[3];

      // Check which token the user received
      for (const change of tokenChanges) {
        if (change.amount > 0) {
          // User received this token
          if (change.mint === noTokenAccount ||
              ix.accounts.indexOf(change.mint) > ix.accounts.indexOf(yesTokenAccount)) {
            direction = "NO";
          }
        }
      }
    } catch {
      // Default to YES if parsing fails
    }
  }

  // Calculate avgPrice - if shares is 0 but amount > 0, estimate from amount
  let avgPrice = 0;
  if (shares > 0) {
    avgPrice = amount / shares;
  } else if (amount > 0) {
    // Estimate: typical prediction market prices are 0.10 - 0.90
    // Without shares, we can't calculate exact price, so use a reasonable estimate
    avgPrice = 0.50; // Will be updated by position lookup if available
  }

  return {
    walletAddress: tx.feePayer,
    signature: tx.signature,
    timestamp: new Date(tx.timestamp * 1000),
    marketAddress: ix.accounts[1],
    direction,
    amount,
    shares,
    avgPrice,
    status: isBuy ? "open" : "claimed",
    canCopy: isBuy,
  };
}

/**
 * Get market info from cache or fetch from API
 * Optimized: Uses parallel fetching for API fallbacks
 */
async function getMarketInfo(address: string, walletAddress?: string): Promise<any | null> {
  try {
    // Check in-memory cache first (fastest)
    const memCached = marketCache.get(address);
    if (memCached && Date.now() - memCached.cachedAt < 3600000) {
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

    // Not cached - fetch from APIs in parallel for better latency
    const fetchPromises: Promise<any | null>[] = [
      fetchMarketFromEvents(address),
    ];

    // Add positions fetch if wallet address provided
    if (walletAddress) {
      fetchPromises.unshift(fetchMarketFromPositions(walletAddress, address));
    }

    const results = await Promise.allSettled(fetchPromises);

    // Return first successful result
    for (const result of results) {
      if (result.status === "fulfilled" && result.value) {
        return result.value;
      }
    }

    return null;
  } catch (error) {
    console.error(`Failed to get market info for ${address}:`, error);
    return null;
  }
}

/**
 * Fetch wallet's position for a specific market to get direction and price
 */
async function fetchWalletPosition(walletAddress: string, marketAddress: string): Promise<{ side: "YES" | "NO"; avgPrice: number; shares: number } | null> {
  try {
    const res = await fetch(
      `${JUPITER_PREDICTION_API}/positions?ownerPubkey=${walletAddress}&limit=50`
    );
    if (!res.ok) return null;

    const data = await res.json() as any;
    const positions = data.data || [];

    // Look for a position that matches this market
    for (const pos of positions) {
      // Check by market ID or address
      if (pos.marketId === marketAddress || pos.market === marketAddress) {
        return {
          side: pos.side?.toUpperCase() === "NO" ? "NO" : "YES",
          avgPrice: pos.avgPrice || pos.averagePrice || 0,
          shares: pos.shares || pos.quantity || 0,
        };
      }
    }

    // If no exact match, return the most recent position as best guess
    // (since we just detected this bet, it's likely their latest position)
    if (positions.length > 0) {
      const pos = positions[0];
      return {
        side: pos.side?.toUpperCase() === "NO" ? "NO" : "YES",
        avgPrice: pos.avgPrice || pos.averagePrice || 0,
        shares: pos.shares || pos.quantity || 0,
      };
    }

    return null;
  } catch {
    return null;
  }
}

/**
 * Fetch market info by looking up wallet's positions
 */
async function fetchMarketFromPositions(walletAddress: string, marketAddress: string): Promise<any | null> {
  try {
    const res = await fetch(
      `${JUPITER_PREDICTION_API}/positions?ownerPubkey=${walletAddress}&limit=50`
    );
    if (!res.ok) return null;

    const data = await res.json() as any;
    const positions = data.data || [];

    // Find position that matches this market (by checking accounts)
    for (const pos of positions) {
      const eventMeta = pos.eventMetadata;
      const marketMeta = pos.marketMetadata;

      if (!eventMeta?.title) continue;

      // Cache all markets we find
      const marketId = pos.marketId || pos.market;
      if (marketId) {
        const info = {
          title: `${eventMeta.title}${marketMeta?.title ? ' - ' + marketMeta.title : ''}`,
          category: eventMeta.category || "Unknown",
          cachedAt: Date.now(),
        };

        marketCache.set(marketId, info);

        // Also save to Firestore
        await db.collection("prediction_markets").doc(marketId).set({
          title: info.title,
          category: info.category,
          eventTitle: eventMeta.title,
          marketTitle: marketMeta?.title,
          isActive: eventMeta.isActive,
          cachedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    }

    // Return the most recent position's market info as best guess
    if (positions.length > 0 && positions[0].eventMetadata) {
      const pos = positions[0];
      return {
        title: `${pos.eventMetadata.title}${pos.marketMetadata?.title ? ' - ' + pos.marketMetadata.title : ''}`,
        category: pos.eventMetadata.category || "Unknown",
      };
    }

    return null;
  } catch {
    return null;
  }
}

/**
 * Fetch market info from active events
 */
async function fetchMarketFromEvents(marketAddress: string): Promise<any | null> {
  try {
    const res = await fetch(`${JUPITER_PREDICTION_API}/events?status=active&limit=20`);
    if (!res.ok) return null;

    const data = await res.json() as any;
    const events = data.data || [];

    for (const event of events) {
      const eventTitle = event.metadata?.title || event.eventId;
      const category = event.category || "Unknown";

      for (const market of event.markets || []) {
        const marketId = market.marketId;
        const fullTitle = `${eventTitle}${market.metadata?.title ? ' - ' + market.metadata.title : ''}`;

        // Cache it
        const info = { title: fullTitle, category, cachedAt: Date.now() };
        marketCache.set(marketId, info);

        // Save to Firestore
        await db.collection("prediction_markets").doc(marketId).set({
          title: fullTitle,
          eventTitle,
          marketTitle: market.metadata?.title,
          category,
          status: market.status,
          cachedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    }

    stats.marketsKnown = marketCache.size;
    return null; // Address matching not implemented yet
  } catch {
    return null;
  }
}

/**
 * Sync market metadata by fetching positions from active wallets
 * This discovers markets by looking at what smart money is betting on
 */
async function syncMarketMetadata() {
  console.log("🔄 Syncing market metadata from Jupiter API...");

  try {
    // Fetch top traders from leaderboard
    const leaderboardRes = await fetch(
      `${JUPITER_PREDICTION_API}/leaderboards?period=weekly&metric=volume&limit=20`
    );

    if (!leaderboardRes.ok) {
      console.error("Failed to fetch leaderboard");
      return;
    }

    const leaderboardData = await leaderboardRes.json() as any;
    const traders = leaderboardData.data || [];

    let marketsFound = 0;

    // Fetch positions for each trader to discover markets
    for (const trader of traders.slice(0, 10)) {
      try {
        const positionsRes = await fetch(
          `${JUPITER_PREDICTION_API}/positions?ownerPubkey=${trader.ownerPubkey}&limit=20`
        );

        if (!positionsRes.ok) continue;

        const positionsData = await positionsRes.json() as any;
        const positions = positionsData.data || [];

        for (const position of positions) {
          const marketId = position.marketId || position.market;
          const eventMeta = position.eventMetadata;
          const marketMeta = position.marketMetadata;

          if (!marketId || !eventMeta?.title) continue;

          // Check if we already have this market
          if (marketCache.has(marketId)) continue;

          // Cache in memory
          marketCache.set(marketId, {
            title: eventMeta.title,
            category: eventMeta.category || "Unknown",
            cachedAt: Date.now(),
          });

          // Save to Firestore
          await db.collection("prediction_markets").doc(marketId).set({
            title: eventMeta.title,
            subtitle: eventMeta.subtitle,
            category: eventMeta.category,
            isActive: eventMeta.isActive,
            marketTitle: marketMeta?.title,
            marketStatus: marketMeta?.status,
            cachedAt: FieldValue.serverTimestamp(),
          }, { merge: true });

          marketsFound++;
        }

        // Rate limit
        await new Promise((r) => setTimeout(r, 200));
      } catch (err) {
        // Ignore individual wallet errors
      }
    }

    stats.marketsKnown = marketCache.size;
    console.log(`✅ Market sync complete: ${marketsFound} new markets, ${marketCache.size} total known`);

    // Also load existing markets from Firestore into memory cache
    const existingMarkets = await db.collection("prediction_markets").limit(200).get();
    existingMarkets.docs.forEach((doc) => {
      const data = doc.data();
      if (data.title && !marketCache.has(doc.id)) {
        marketCache.set(doc.id, {
          title: data.title,
          category: data.category || "Unknown",
          cachedAt: Date.now(),
        });
      }
    });

    stats.marketsKnown = marketCache.size;
  } catch (error) {
    console.error("Market sync error:", error);
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
