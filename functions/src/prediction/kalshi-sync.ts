/**
 * Kalshi Market Sync
 *
 * Jupiter Prediction uses Kalshi as its data source.
 * Markets can be matched EXACTLY by event_ticker (e.g., "KXSB-26")
 * This gives us real-time Kalshi prices to compare with Jupiter execution prices.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { KALSHI_API, KALSHI_SIGNAL_THRESHOLDS } from "./kalshi-config";

const db = getFirestore();

interface KalshiEvent {
  event_ticker: string;
  series_ticker: string;
  title: string;
  sub_title: string;
  category: string;
  mutually_exclusive: boolean;
}

interface KalshiMarket {
  ticker: string;
  event_ticker: string;
  title: string;
  subtitle: string;
  status: string;
  yes_bid: number;
  yes_ask: number;
  no_bid: number;
  no_ask: number;
  last_price: number;
  volume: number;
  volume_24h: number;
  open_interest: number;
  liquidity: number;
  close_time: string;
}

interface JupiterMarket {
  id: string;
  eventId: string;
  title: string;
  category?: string;
}

/**
 * Sync Kalshi markets - DISABLED to save API costs
 * Was running every 15 minutes making expensive Kalshi API calls
 */
export const syncKalshiMarkets = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "America/New_York",
    retryCount: 0,
  },
  async () => {
    // DISABLED - Kalshi API calls are expensive
    logger.info("Kalshi sync DISABLED to save costs");
    return;
  }
);

/**
 * Manual sync trigger - DISABLED to save API costs
 */
export const syncKalshiNow = onCall(
  { cors: true },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    // DISABLED - Kalshi API calls are expensive
    logger.info("Manual Kalshi sync DISABLED to save costs");
    return {
      success: false,
      message: "Kalshi sync disabled to save API costs",
    };
  }
);

/**
 * Get Kalshi signals for a market
 */
export const getKalshiSignals = onCall(
  { cors: true },
  async (request) => {
    const { marketId, limit = 20 } = request.data || {};

    let query = db.collection("kalshi_signals")
      .orderBy("createdAt", "desc")
      .limit(limit);

    if (marketId) {
      query = db.collection("kalshi_signals")
        .where("jupiterMarketId", "==", marketId)
        .orderBy("createdAt", "desc")
        .limit(limit);
    }

    const snapshot = await query.get();

    return {
      signals: snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      })),
    };
  }
);

/**
 * Fetch Kalshi data for specific Jupiter market tickers
 * Jupiter stores Kalshi market tickers (e.g., "KXARREST-27JAN-AFAU"), not event tickers
 */
async function fetchKalshiDataForEvents(marketTickers: string[]): Promise<{ events: KalshiEvent[]; markets: KalshiMarket[] }> {
  const events: KalshiEvent[] = [];
  const markets: KalshiMarket[] = [];
  const seenEventTickers = new Set<string>();

  // Fetch each market directly from Kalshi (batch in parallel, limit concurrency)
  const batchSize = 10;
  for (let i = 0; i < marketTickers.length; i += batchSize) {
    const batch = marketTickers.slice(i, i + batchSize);
    const results = await Promise.allSettled(
      batch.map(async (ticker) => {
        try {
          const res = await fetch(`${KALSHI_API}/markets/${ticker}`);
          if (!res.ok) return null;
          const data = await res.json() as { market: KalshiMarket };
          return data.market;
        } catch {
          return null;
        }
      })
    );

    for (const result of results) {
      if (result.status === "fulfilled" && result.value) {
        const market = result.value;
        markets.push(market);

        // Create a synthetic event from market data if we haven't seen this event
        if (!seenEventTickers.has(market.event_ticker)) {
          seenEventTickers.add(market.event_ticker);
          events.push({
            event_ticker: market.event_ticker,
            series_ticker: "",
            title: market.title,
            sub_title: market.subtitle || "",
            category: "",
            mutually_exclusive: false,
          });
        }
      }
    }
  }

  return { events, markets };
}

/**
 * Load Jupiter markets from Firestore
 * Returns map of event_ticker -> market info
 */
async function loadJupiterMarkets(): Promise<Map<string, JupiterMarket>> {
  const snapshot = await db.collection("prediction_markets").get();

  const markets = new Map<string, JupiterMarket>();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    // Jupiter markets have eventId in format "KXSB-26" which matches Kalshi event_ticker
    const eventId = data.eventId || doc.id;

    // Only add if it looks like a Kalshi ticker
    if (eventId.startsWith("KX")) {
      markets.set(eventId, {
        id: doc.id,
        eventId,
        title: data.title || "",
        category: data.category,
      });
    }
  }

  return markets;
}

/**
 * Create a Kalshi price signal
 */
async function createKalshiSignal(
  market: KalshiMarket,
  event: KalshiEvent | undefined,
  prevPrice: number,
  newPrice: number,
  jupiterMatch: JupiterMarket
): Promise<void> {
  const priceChange = newPrice - prevPrice;
  const direction = priceChange > 0 ? "YES" : "NO";

  await db.collection("kalshi_signals").add({
    source: "kalshi",
    kalshiTicker: market.ticker,
    kalshiEventTicker: market.event_ticker,
    kalshiTitle: market.title,
    eventTitle: event?.title || "",
    category: event?.category || "",
    // Jupiter target
    jupiterMarketId: jupiterMatch.id,
    jupiterEventId: jupiterMatch.eventId,
    jupiterTitle: jupiterMatch.title,
    // Signal data
    direction,
    priceChange: Math.abs(priceChange),
    kalshiPrice: newPrice,
    previousPrice: prevPrice,
    volume: market.volume,
    volume24h: market.volume_24h,
    liquidity: market.liquidity,
    signalStrength: calculateSignalStrength(Math.abs(priceChange), market.volume),
    createdAt: FieldValue.serverTimestamp(),
    status: "pending",
  });

  logger.info(
    `Kalshi signal: ${market.event_ticker} moved ${(priceChange * 100).toFixed(1)}% toward ${direction}`
  );
}

/**
 * Calculate signal strength (0-100)
 */
function calculateSignalStrength(priceChange: number, volume: number): number {
  const priceScore = Math.min(priceChange * 500, 50);
  const volumeScore = Math.min(Math.log10(volume + 1) * 10, 50);
  return Math.round(priceScore + volumeScore);
}
