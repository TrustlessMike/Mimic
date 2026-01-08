import { db } from '@/lib/firebase';
import { NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const snapshot = await db
      .collection('prediction_markets')
      .orderBy('cachedAt', 'desc')
      .limit(100)
      .get();

    const markets = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        title: data.title,
        eventTitle: data.eventTitle,
        marketTitle: data.marketTitle,
        category: data.category,
        status: data.status,
        isActive: data.isActive,
      };
    });

    return NextResponse.json({ markets, count: markets.length });
  } catch (error) {
    console.error('Error fetching markets:', error);
    return NextResponse.json({ error: 'Failed to fetch markets' }, { status: 500 });
  }
}
