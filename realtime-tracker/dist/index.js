"use strict";
/**
 * Helius WebSocket Real-Time Smart Money Tracker
 *
 * FASTEST method - sub-second latency (~500-800ms from block to notification)
 *
 * Deploy: gcloud run deploy helius-realtime --source . --min-instances=1
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const messaging_1 = require("firebase-admin/messaging");
const ws_1 = __importDefault(require("ws"));
const http_1 = __importDefault(require("http"));
// Initialize Firebase
if (!(0, app_1.getApps)().length) {
    (0, app_1.initializeApp)();
}
const db = (0, firestore_1.getFirestore)();
// Config
const HELIUS_API_KEY = process.env.HELIUS_API_KEY;
const HELIUS_WS_URL = `wss://mainnet.helius-rpc.com/?api-key=${HELIUS_API_KEY}`;
const PORT = process.env.PORT || 8080;
// Jupiter Prediction Program
const JUPITER_PREDICTION_PROGRAM = "3ZZuTbwC6aJbvteyVxXUS7gtFYdf7AuXeitx6VyvjvUp";
const USDC_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v";
// Smart money wallets cache
let smartMoneyWallets = new Map();
// Market metadata cache (in-memory for quick lookups)
let marketCache = new Map();
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
    const server = http_1.default.createServer((req, res) => {
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
        }
        else {
            res.writeHead(404);
            res.end();
        }
    });
    await new Promise((resolve) => {
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
    }
    catch (error) {
        console.error("Failed to initialize tracking:", error);
        // Keep server running for health checks even if tracking fails
    }
}
/**
 * Connect to Helius WebSocket
 */
function connectWebSocket() {
    console.log("📡 Connecting to Helius WebSocket...");
    const ws = new ws_1.default(HELIUS_WS_URL);
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
        }
        catch (error) {
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
        if (ws.readyState === ws_1.default.OPEN) {
            ws.ping();
        }
    }, 30000);
}
/**
 * Process transaction
 */
async function processTransaction(signature) {
    const startTime = Date.now();
    try {
        // Fetch enhanced transaction
        const response = await fetch(`https://api.helius.xyz/v0/transactions/?api-key=${HELIUS_API_KEY}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ transactions: [signature] }),
        });
        const txData = await response.json();
        const tx = txData[0];
        if (!tx)
            return;
        // Check if smart money
        const walletInfo = smartMoneyWallets.get(tx.feePayer);
        if (!walletInfo)
            return;
        // Parse bet
        const bet = parseBet(tx);
        if (!bet || bet.amount === 0)
            return;
        bet.walletNickname = walletInfo.nickname;
        // Get market info
        const market = await getMarketInfo(bet.marketAddress);
        if (market) {
            bet.marketTitle = market.title;
            bet.marketCategory = market.category;
        }
        // Save to Firestore
        await db.collection("prediction_bets").doc(signature).set({
            ...bet,
            source: "realtime_websocket",
            latencyMs: Date.now() - startTime,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
        });
        stats.betsFound++;
        // Send push notification
        await sendNotification(bet);
        console.log(`⚡ [${Date.now() - startTime}ms] ${walletInfo.nickname || tx.feePayer.slice(0, 8)}... ` +
            `${bet.direction} $${bet.amount.toFixed(2)} "${bet.marketTitle || ""}"`);
    }
    catch (error) {
        // Silently ignore - not all program txs are bets
    }
}
/**
 * Parse bet from transaction
 */
function parseBet(tx) {
    const ix = tx.instructions?.find((i) => i.programId === JUPITER_PREDICTION_PROGRAM);
    if (!ix)
        return null;
    let usdcChange = 0;
    let shares = 0;
    const outcomeToken = ix.accounts[3];
    for (const acc of tx.accountData || []) {
        for (const change of acc.tokenBalanceChanges || []) {
            if (change.mint === USDC_MINT && change.userAccount === tx.feePayer) {
                usdcChange = parseFloat(change.rawTokenAmount.tokenAmount) / 1e6;
            }
            if (change.mint === outcomeToken && change.userAccount === tx.feePayer) {
                shares = Math.abs(parseFloat(change.rawTokenAmount.tokenAmount) / 1e6);
            }
        }
    }
    const isBuy = usdcChange < 0;
    const amount = Math.abs(usdcChange);
    return {
        walletAddress: tx.feePayer,
        signature: tx.signature,
        timestamp: new Date(tx.timestamp * 1000),
        marketAddress: ix.accounts[1],
        direction: "YES", // Determined by market lookup
        amount,
        shares,
        avgPrice: shares > 0 ? amount / shares : 0,
        status: isBuy ? "open" : "claimed",
        canCopy: isBuy,
    };
}
/**
 * Get market info from cache (in-memory first, then Firestore)
 */
async function getMarketInfo(address) {
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
            // Update in-memory cache
            if (data?.title) {
                marketCache.set(address, {
                    title: data.title,
                    category: data.category || "Unknown",
                    cachedAt: Date.now(),
                });
            }
            return data;
        }
        return null;
    }
    catch {
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
        const leaderboardRes = await fetch(`${JUPITER_PREDICTION_API}/leaderboards?period=weekly&metric=volume&limit=20`);
        if (!leaderboardRes.ok) {
            console.error("Failed to fetch leaderboard");
            return;
        }
        const leaderboardData = await leaderboardRes.json();
        const traders = leaderboardData.data || [];
        let marketsFound = 0;
        // Fetch positions for each trader to discover markets
        for (const trader of traders.slice(0, 10)) {
            try {
                const positionsRes = await fetch(`${JUPITER_PREDICTION_API}/positions?ownerPubkey=${trader.ownerPubkey}&limit=20`);
                if (!positionsRes.ok)
                    continue;
                const positionsData = await positionsRes.json();
                const positions = positionsData.data || [];
                for (const position of positions) {
                    const marketId = position.marketId || position.market;
                    const eventMeta = position.eventMetadata;
                    const marketMeta = position.marketMetadata;
                    if (!marketId || !eventMeta?.title)
                        continue;
                    // Check if we already have this market
                    if (marketCache.has(marketId))
                        continue;
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
                        cachedAt: firestore_1.FieldValue.serverTimestamp(),
                    }, { merge: true });
                    marketsFound++;
                }
                // Rate limit
                await new Promise((r) => setTimeout(r, 200));
            }
            catch (err) {
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
    }
    catch (error) {
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
async function sendNotification(bet) {
    try {
        const users = await db.collection("users")
            .where("notificationsEnabled", "==", true)
            .get();
        const tokens = [];
        users.docs.forEach((doc) => {
            const data = doc.data();
            if (data.fcmTokens?.length)
                tokens.push(...data.fcmTokens);
        });
        if (!tokens.length)
            return;
        const name = bet.walletNickname || bet.walletAddress.slice(0, 8) + "...";
        for (let i = 0; i < tokens.length; i += 500) {
            await (0, messaging_1.getMessaging)().sendEachForMulticast({
                tokens: tokens.slice(i, i + 500),
                notification: {
                    title: `⚡ ${name} placed a bet`,
                    body: `${bet.direction} on "${bet.marketTitle || "market"}" - $${bet.amount.toFixed(2)}`,
                },
                data: { type: "smart_money_bet", signature: bet.signature },
                apns: { payload: { aps: { sound: "default" } } },
            });
        }
    }
    catch (error) {
        console.error("Notification error:", error);
    }
}
// Start
start().catch(console.error);
