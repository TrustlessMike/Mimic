import { db } from '@/lib/firebase';
import { validateApiKey } from '@/lib/auth';
import { NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  const authError = validateApiKey(request);
  if (authError) return authError;

  try {
    const { searchParams } = new URL(request.url);
    const category = searchParams.get('category');
    const limit = parseInt(searchParams.get('limit') || '50');

    let query = db
      .collection('kalshi_markets')
      .orderBy('volume', 'desc')
      .limit(limit);

    if (category) {
      query = db
        .collection('kalshi_markets')
        .where('category', '==', category)
        .orderBy('volume', 'desc')
        .limit(limit);
    }

    const snapshot = await query.get();

    const markets = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        ticker: data.ticker,
        eventTicker: data.eventTicker,
        title: data.title,
        eventTitle: data.eventTitle,
        category: data.category,
        yesBid: data.yesBid,
        yesAsk: data.yesAsk,
        midPrice: data.midPrice,
        spread: data.spread,
        volume: data.volume,
        volume24h: data.volume24h,
        liquidity: data.liquidity,
        // Jupiter match
        jupiterMarketId: data.jupiterMarketId,
        jupiterEventId: data.jupiterEventId,
        jupiterTitle: data.jupiterTitle,
        matchType: data.matchType,
        lastSyncedAt: data.lastSyncedAt?.toDate?.()?.toISOString(),
      };
    });

    return NextResponse.json({ markets, count: markets.length });
  } catch (error) {
    console.error('Error fetching kalshi markets:', error);
    return NextResponse.json({ error: 'Failed to fetch kalshi data' }, { status: 500 });
  }
}
