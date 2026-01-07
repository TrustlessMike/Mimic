import { useState, useEffect, useCallback } from 'react';
import {
  collection,
  query,
  orderBy,
  limit,
  getDocs,
  getCountFromServer,
} from 'firebase/firestore';
import { db } from '../services/firebase';
import type { PolymarketMarket, CrossPlatformSignal, ArbitrageOpportunity } from '../types';

// Simple in-memory cache with TTL
const cache = new Map<string, { data: unknown; timestamp: number }>();
const CACHE_TTL = 30000; // 30 seconds

function getCached<T>(key: string): T | null {
  const cached = cache.get(key);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data as T;
  }
  cache.delete(key);
  return null;
}

function setCache<T>(key: string, data: T): void {
  cache.set(key, { data, timestamp: Date.now() });
}

export function usePolymarketMarkets(limitCount = 50) {
  const [markets, setMarkets] = useState<PolymarketMarket[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `polymarket-markets-${limitCount}`;

  const fetchMarkets = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<PolymarketMarket[]>(cacheKey);
      if (cached) {
        setMarkets(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const q = query(
        collection(db, 'polymarket_markets'),
        orderBy('volume', 'desc'),
        limit(limitCount)
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({
        id: doc.id,
        conditionId: doc.id,
        ...doc.data()
      } as PolymarketMarket));

      setCache(cacheKey, data);
      setMarkets(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch Polymarket markets');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, limitCount]);

  useEffect(() => {
    fetchMarkets();
  }, [fetchMarkets]);

  const refetch = useCallback(() => fetchMarkets(true), [fetchMarkets]);

  return { markets, loading, error, refetch };
}

export function useCrossPlatformSignals(limitCount = 50) {
  const [signals, setSignals] = useState<CrossPlatformSignal[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `cross-platform-signals-${limitCount}`;

  const fetchSignals = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<CrossPlatformSignal[]>(cacheKey);
      if (cached) {
        setSignals(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const q = query(
        collection(db, 'cross_platform_signals'),
        orderBy('createdAt', 'desc'),
        limit(limitCount)
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as CrossPlatformSignal));

      setCache(cacheKey, data);
      setSignals(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch cross-platform signals');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, limitCount]);

  useEffect(() => {
    fetchSignals();
  }, [fetchSignals]);

  const refetch = useCallback(() => fetchSignals(true), [fetchSignals]);

  return { signals, loading, error, refetch };
}

export function useArbitrageOpportunities(limitCount = 20) {
  const [opportunities, setOpportunities] = useState<ArbitrageOpportunity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `arbitrage-opportunities-${limitCount}`;

  const fetchOpportunities = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<ArbitrageOpportunity[]>(cacheKey);
      if (cached) {
        setOpportunities(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const q = query(
        collection(db, 'arbitrage_opportunities'),
        orderBy('spreadPct', 'desc'),
        limit(limitCount)
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as ArbitrageOpportunity));

      setCache(cacheKey, data);
      setOpportunities(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch arbitrage opportunities');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, limitCount]);

  useEffect(() => {
    fetchOpportunities();
  }, [fetchOpportunities]);

  const refetch = useCallback(() => fetchOpportunities(true), [fetchOpportunities]);

  return { opportunities, loading, error, refetch };
}

export interface PolymarketStats {
  totalMatchedMarkets: number;
  totalSignals: number;
  activeArbitrageOpportunities: number;
  avgMatchConfidence: number;
}

export function usePolymarketStats() {
  const [stats, setStats] = useState<PolymarketStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = 'polymarket-stats';

  const fetchStats = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<PolymarketStats>(cacheKey);
      if (cached) {
        setStats(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const [marketsCount, signalsCount, arbCount] = await Promise.all([
        getCountFromServer(collection(db, 'polymarket_markets')),
        getCountFromServer(collection(db, 'cross_platform_signals')),
        getCountFromServer(collection(db, 'arbitrage_opportunities')),
      ]);

      // Calculate average match confidence from top markets
      const marketsQuery = query(
        collection(db, 'polymarket_markets'),
        orderBy('volume', 'desc'),
        limit(50)
      );
      const marketsSnapshot = await getDocs(marketsQuery);
      let totalConfidence = 0;
      let confidenceCount = 0;
      marketsSnapshot.docs.forEach(doc => {
        const data = doc.data();
        if (data.matchConfidence) {
          totalConfidence += data.matchConfidence;
          confidenceCount++;
        }
      });

      const data: PolymarketStats = {
        totalMatchedMarkets: marketsCount.data().count,
        totalSignals: signalsCount.data().count,
        activeArbitrageOpportunities: arbCount.data().count,
        avgMatchConfidence: confidenceCount > 0 ? Math.round(totalConfidence / confidenceCount) : 0,
      };

      setCache(cacheKey, data);
      setStats(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch Polymarket stats');
    } finally {
      setLoading(false);
    }
  }, [cacheKey]);

  useEffect(() => {
    fetchStats();
  }, [fetchStats]);

  const refetch = useCallback(() => fetchStats(true), [fetchStats]);

  return { stats, loading, error, refetch };
}
