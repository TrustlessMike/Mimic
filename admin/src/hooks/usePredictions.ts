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
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../services/firebase';
import type { SmartMoneyWallet, PredictionBet, BetDirection, BetStatus } from '../types';

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

export function useSmartMoneyWallets(limitCount = 100) {
  const [wallets, setWallets] = useState<SmartMoneyWallet[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `smart-money-wallets-${limitCount}`;

  const fetchWallets = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<SmartMoneyWallet[]>(cacheKey);
      if (cached) {
        setWallets(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const q = query(
        collection(db, 'smart_money_wallets'),
        where('isActive', '==', true),
        orderBy('addedAt', 'desc'),
        limit(limitCount)
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as SmartMoneyWallet));

      setCache(cacheKey, data);
      setWallets(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch smart money wallets');
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

export interface PredictionBetFilter {
  direction?: BetDirection;
  status?: BetStatus;
}

export function usePredictionBets(filter?: PredictionBetFilter, limitCount = 100) {
  const [bets, setBets] = useState<PredictionBet[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `prediction-bets-${filter?.direction}-${filter?.status}-${limitCount}`;

  const fetchBets = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<PredictionBet[]>(cacheKey);
      if (cached) {
        setBets(cached);
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

      if (filter?.direction) {
        constraints.unshift(where('direction', '==', filter.direction));
      }
      if (filter?.status) {
        constraints.unshift(where('status', '==', filter.status));
      }

      const q = query(collection(db, 'prediction_bets'), ...constraints);
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as PredictionBet));

      setCache(cacheKey, data);
      setBets(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch prediction bets');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, filter?.direction, filter?.status, limitCount]);

  useEffect(() => {
    fetchBets();
  }, [fetchBets]);

  const refetch = useCallback(() => fetchBets(true), [fetchBets]);

  return { bets, loading, error, refetch };
}

export interface PredictionStats {
  totalSmartMoneyWallets: number;
  totalPredictionBets: number;
  activeBets: number;
  betsLast24h: number;
}

export function usePredictionStats() {
  const [stats, setStats] = useState<PredictionStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = 'prediction-stats';

  const fetchStats = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<PredictionStats>(cacheKey);
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

      const [walletsCount, totalBetsCount, activeBetsCount, recentBetsCount] = await Promise.all([
        getCountFromServer(query(
          collection(db, 'smart_money_wallets'),
          where('isActive', '==', true)
        )),
        getCountFromServer(collection(db, 'prediction_bets')),
        getCountFromServer(query(
          collection(db, 'prediction_bets'),
          where('status', '==', 'open')
        )),
        getCountFromServer(query(
          collection(db, 'prediction_bets'),
          where('timestamp', '>=', twentyFourHoursAgo)
        ))
      ]);

      const data: PredictionStats = {
        totalSmartMoneyWallets: walletsCount.data().count,
        totalPredictionBets: totalBetsCount.data().count,
        activeBets: activeBetsCount.data().count,
        betsLast24h: recentBetsCount.data().count,
      };

      setCache(cacheKey, data);
      setStats(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch prediction stats');
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

// Cloud function calls for admin operations
export function useAddSmartMoneyWallet() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const addWallet = useCallback(async (address: string, nickname?: string, notes?: string) => {
    setLoading(true);
    setError(null);
    try {
      const addSmartMoneyWalletFn = httpsCallable(functions, 'addSmartMoneyWallet');
      await addSmartMoneyWalletFn({ address, nickname, notes });
      return true;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to add wallet';
      setError(message);
      return false;
    } finally {
      setLoading(false);
    }
  }, []);

  return { addWallet, loading, error };
}

export function useRemoveSmartMoneyWallet() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const removeWallet = useCallback(async (address: string) => {
    setLoading(true);
    setError(null);
    try {
      const removeSmartMoneyWalletFn = httpsCallable(functions, 'removeSmartMoneyWallet');
      await removeSmartMoneyWalletFn({ address });
      return true;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to remove wallet';
      setError(message);
      return false;
    } finally {
      setLoading(false);
    }
  }, []);

  return { removeWallet, loading, error };
}
