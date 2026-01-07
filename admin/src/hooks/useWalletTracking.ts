import { useState, useEffect, useCallback } from 'react';
import {
  collection,
  query,
  orderBy,
  limit,
  getDocs,
  getCountFromServer,
  where,
  Timestamp,
  QueryConstraint,
} from 'firebase/firestore';
import { db } from '../services/firebase';
import type { TrackedWallet, TrackedTrade, CopyBot, CopyTradeLog, TradeType } from '../types';

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

export function useTrackedWallets(limitCount = 100) {
  const [wallets, setWallets] = useState<TrackedWallet[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `tracked-wallets-${limitCount}`;

  const fetchWallets = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<TrackedWallet[]>(cacheKey);
      if (cached) {
        setWallets(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const q = query(
        collection(db, 'tracked_wallets'),
        orderBy('createdAt', 'desc'),
        limit(limitCount)
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as TrackedWallet));

      setCache(cacheKey, data);
      setWallets(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch tracked wallets');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, limitCount]);

  useEffect(() => {
    fetchWallets();
  }, [fetchWallets]);

  const refetch = useCallback(() => fetchWallets(true), [fetchWallets]);

  return { wallets, loading, error, refetch };
}

export interface TrackedTradeFilter {
  type?: TradeType;
  safeMode?: boolean;
}

export function useTrackedTrades(filter?: TrackedTradeFilter, limitCount = 100) {
  const [trades, setTrades] = useState<TrackedTrade[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `tracked-trades-${filter?.type}-${filter?.safeMode}-${limitCount}`;

  const fetchTrades = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<TrackedTrade[]>(cacheKey);
      if (cached) {
        setTrades(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const constraints: QueryConstraint[] = [
        orderBy('timestamp', 'desc'),
        limit(limitCount)
      ];

      if (filter?.type) {
        constraints.unshift(where('type', '==', filter.type));
      }
      if (filter?.safeMode !== undefined) {
        constraints.unshift(where('isSafeModeTrade', '==', filter.safeMode));
      }

      const q = query(collection(db, 'tracked_trades'), ...constraints);
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as TrackedTrade));

      setCache(cacheKey, data);
      setTrades(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch tracked trades');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, filter?.type, filter?.safeMode, limitCount]);

  useEffect(() => {
    fetchTrades();
  }, [fetchTrades]);

  const refetch = useCallback(() => fetchTrades(true), [fetchTrades]);

  return { trades, loading, error, refetch };
}

export function useCopyBots(limitCount = 100) {
  const [bots, setBots] = useState<CopyBot[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `copy-bots-${limitCount}`;

  const fetchBots = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<CopyBot[]>(cacheKey);
      if (cached) {
        setBots(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const q = query(
        collection(db, 'copy_bots'),
        orderBy('createdAt', 'desc'),
        limit(limitCount)
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as CopyBot));

      setCache(cacheKey, data);
      setBots(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch copy bots');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, limitCount]);

  useEffect(() => {
    fetchBots();
  }, [fetchBots]);

  const refetch = useCallback(() => fetchBots(true), [fetchBots]);

  return { bots, loading, error, refetch };
}

export function useCopyTradeLogs(limitCount = 100) {
  const [logs, setLogs] = useState<CopyTradeLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `copy-trade-logs-${limitCount}`;

  const fetchLogs = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<CopyTradeLog[]>(cacheKey);
      if (cached) {
        setLogs(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const q = query(
        collection(db, 'copy_trade_logs'),
        orderBy('createdAt', 'desc'),
        limit(limitCount)
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as CopyTradeLog));

      setCache(cacheKey, data);
      setLogs(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch copy trade logs');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, limitCount]);

  useEffect(() => {
    fetchLogs();
  }, [fetchLogs]);

  const refetch = useCallback(() => fetchLogs(true), [fetchLogs]);

  return { logs, loading, error, refetch };
}

export interface WalletTrackingStats {
  totalTrackedWallets: number;
  totalTrackedTrades: number;
  activeCopyBots: number;
  copyTradesLast24h: number;
}

export interface RealtimeTrackerStatus {
  status: string;
  connected: boolean;
  uptime: number;
  txProcessed: number;
  betsFound: number;
  walletsTracked: number;
  lastMessage: string | null;
}

const TRACKER_URL = 'https://helius-realtime-tracker-846808776557.us-central1.run.app/health';

export function useRealtimeTrackerStatus() {
  const [trackerStatus, setTrackerStatus] = useState<RealtimeTrackerStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchStatus = useCallback(async () => {
    setLoading(true);
    try {
      const response = await fetch(TRACKER_URL);
      if (!response.ok) throw new Error('Failed to fetch tracker status');
      const data = await response.json();
      setTrackerStatus(data);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch tracker status');
      setTrackerStatus(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchStatus();
    // Refresh every 30 seconds
    const interval = setInterval(fetchStatus, 30000);
    return () => clearInterval(interval);
  }, [fetchStatus]);

  return { trackerStatus, loading, error, refetch: fetchStatus };
}

export function useWalletTrackingStats() {
  const [stats, setStats] = useState<WalletTrackingStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = 'wallet-tracking-stats';

  const fetchStats = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<WalletTrackingStats>(cacheKey);
      if (cached) {
        setStats(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const twentyFourHoursAgo = Timestamp.fromDate(
        new Date(Date.now() - 24 * 60 * 60 * 1000)
      );

      const [walletsCount, tradesCount, activeBotsCount, recentCopyTradesCount] = await Promise.all([
        getCountFromServer(collection(db, 'tracked_wallets')),
        getCountFromServer(collection(db, 'tracked_trades')),
        getCountFromServer(query(
          collection(db, 'copy_bots'),
          where('isActive', '==', true)
        )),
        getCountFromServer(query(
          collection(db, 'copy_trade_logs'),
          where('createdAt', '>=', twentyFourHoursAgo)
        ))
      ]);

      const data: WalletTrackingStats = {
        totalTrackedWallets: walletsCount.data().count,
        totalTrackedTrades: tradesCount.data().count,
        activeCopyBots: activeBotsCount.data().count,
        copyTradesLast24h: recentCopyTradesCount.data().count,
      };

      setCache(cacheKey, data);
      setStats(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch wallet tracking stats');
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
