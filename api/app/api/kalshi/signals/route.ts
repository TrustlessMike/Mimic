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
    const limit = parseInt(searchParams.get('limit') || '20');
    const status = searchParams.get('status'); // pending, acted, expired

    let query = db
      .collection('kalshi_signals')
      .orderBy('createdAt', 'desc')
      .limit(limit);

    if (status) {
      query = db
        .collection('kalshi_signals')
        .where('status', '==', status)
        .orderBy('createdAt', 'desc')
        .limit(limit);
    }

    const snapshot = await query.get();

    const signals = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        kalshiTicker: data.kalshiTicker,
        kalshiEventTicker: data.kalshiEventTicker,
        kalshiTitle: data.kalshiTitle,
        eventTitle: data.eventTitle,
        category: data.category,
        // Jupiter target
        jupiterMarketId: data.jupiterMarketId,
        jupiterEventId: data.jupiterEventId,
        jupiterTitle: data.jupiterTitle,
        // Signal data
        direction: data.direction,
        priceChange: data.priceChange,
        kalshiPrice: data.kalshiPrice,
        previousPrice: data.previousPrice,
        volume: data.volume,
        signalStrength: data.signalStrength,
        status: data.status,
        createdAt: data.createdAt?.toDate?.()?.toISOString(),
      };
    });

    return NextResponse.json({ signals, count: signals.length });
  } catch (error) {
    console.error('Error fetching kalshi signals:', error);
    return NextResponse.json({ error: 'Failed to fetch signals' }, { status: 500 });
  }
}
