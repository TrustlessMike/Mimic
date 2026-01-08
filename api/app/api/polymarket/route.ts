import { db } from '@/lib/firebase';
import { NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const snapshot = await db
      .collection('polymarket_markets')
      .orderBy('volume', 'desc')
      .limit(50)
      .get();

    const markets = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        conditionId: data.conditionId,
        question: data.question,
        eventTitle: data.eventTitle,
        volume: data.volume,
        yesPrice: data.yesPrice,
        jupiterMarketId: data.jupiterMarketId,
        jupiterMarketTitle: data.jupiterMarketTitle,
        matchConfidence: data.matchConfidence,
      };
    });

    return NextResponse.json({ markets, count: markets.length });
  } catch (error) {
    console.error('Error fetching polymarket:', error);
    return NextResponse.json({ error: 'Failed to fetch polymarket data' }, { status: 500 });
  }
}
