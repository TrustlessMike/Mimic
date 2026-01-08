import { NextResponse } from 'next/server';

export const runtime = 'nodejs'; // Changed to nodejs for auth middleware
export const dynamic = 'force-dynamic';

// Health check is public - no auth required (for uptime monitoring)
export async function GET() {
  return NextResponse.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'mimic-api',
  });
}
