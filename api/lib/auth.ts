import { NextResponse } from 'next/server';

// API key for dashboard access - set in Vercel environment variables
const API_KEY = process.env.DASHBOARD_API_KEY;

export function validateApiKey(request: Request): NextResponse | null {
  // Check for API key in header
  const providedKey = request.headers.get('x-api-key');

  if (!API_KEY) {
    console.error('DASHBOARD_API_KEY not configured');
    return NextResponse.json({ error: 'Server misconfigured' }, { status: 500 });
  }

  if (!providedKey || providedKey !== API_KEY) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  return null; // Valid - proceed with request
}
