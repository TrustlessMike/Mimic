import { db } from '@/lib/firebase';
import { NextResponse } from 'next/server';

export const runtime = 'nodejs'; // Serverless (firebase-admin needs Node.js)
export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '50');
    const direction = searchParams.get('direction'); // YES or NO

    let query = db.collection('prediction_bets').orderBy('timestamp', 'desc');

    if (direction) {
      query = query.where('direction', '==', direction);
    }

    const snapshot = await query.limit(limit).get();

    const bets = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        walletAddress: data.walletAddress,
        walletNickname: data.walletNickname,
        marketTitle: data.marketTitle,
        direction: data.direction,
        amount: data.amount,
        shares: data.shares,
        avgPrice: data.avgPrice,
        timestamp: data.timestamp?.toDate?.()?.toISOString(),
        signature: data.signature,
      };
    });

    return NextResponse.json({ bets, count: bets.length });
  } catch (error) {
    console.error('Error fetching bets:', error);
    return NextResponse.json({ error: 'Failed to fetch bets' }, { status: 500 });
  }
}
