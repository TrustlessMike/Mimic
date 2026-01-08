import { db } from '@/lib/firebase';
import { NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const snapshot = await db
      .collection('smart_money_wallets')
      .where('isActive', '==', true)
      .limit(100)
      .get();

    const wallets = snapshot.docs.map((doc) => ({
      id: doc.id,
      address: doc.data().address,
      nickname: doc.data().nickname,
      stats: doc.data().stats,
    }));

    return NextResponse.json({ wallets, count: wallets.length });
  } catch (error) {
    console.error('Error fetching wallets:', error);
    return NextResponse.json({ error: 'Failed to fetch wallets' }, { status: 500 });
  }
}
