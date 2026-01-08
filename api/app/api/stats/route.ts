import { db } from '@/lib/firebase';
import { validateApiKey } from '@/lib/auth';
import { NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  const authError = validateApiKey(request);
  if (authError) return authError;

  try {
    // Parallel queries for speed
    const [walletsSnap, betsSnap, marketsSnap, polySnap] = await Promise.all([
      db.collection('smart_money_wallets').where('isActive', '==', true).count().get(),
      db.collection('prediction_bets').count().get(),
      db.collection('prediction_markets').count().get(),
      db.collection('polymarket_markets').count().get(),
    ]);

    // Get recent bet volume
    const recentBets = await db
      .collection('prediction_bets')
      .orderBy('timestamp', 'desc')
      .limit(100)
      .get();

    let totalVolume = 0;
    let yesCount = 0;
    let noCount = 0;

    recentBets.docs.forEach((doc) => {
      const data = doc.data();
      totalVolume += data.amount || 0;
      if (data.direction === 'YES') yesCount++;
      else noCount++;
    });

    return NextResponse.json({
      wallets: walletsSnap.data().count,
      bets: betsSnap.data().count,
      markets: marketsSnap.data().count,
      polymarketMatches: polySnap.data().count,
      recent: {
        volume: totalVolume,
        yesCount,
        noCount,
      },
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    return NextResponse.json({ error: 'Failed to fetch stats' }, { status: 500 });
  }
}
