import { NextResponse } from 'next/server';

export const runtime = 'edge'; // Health check can be edge - no firebase needed

export async function GET() {
  return NextResponse.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'mimic-api',
  });
}
