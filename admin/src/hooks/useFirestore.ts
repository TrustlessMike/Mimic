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
import type { User, Transaction, SolanaTransaction, PaymentRequest, AutoSwapLog, DashboardStats, CoinbaseOnrampSession, CoinbaseOfframpSession } from '../types';

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

export function useUsers(limitCount = 100) {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `users-${limitCount}`;

  const fetchUsers = useCallback(async (skipCache = false) => {
    // Check cache first
    if (!skipCache) {
      const cached = getCached<User[]>(cacheKey);
      if (cached) {
        setUsers(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const q = query(
        collection(db, 'users'),
        limit(limitCount)
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as User));

      data.sort((a, b) => {
        const aTime = a.createdAt?.toMillis?.() || 0;
        const bTime = b.createdAt?.toMillis?.() || 0;
        return bTime - aTime;
      });

      setCache(cacheKey, data);
      setUsers(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch users');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, limitCount]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const refetch = useCallback(() => fetchUsers(true), [fetchUsers]);

  return { users, loading, error, refetch };
}

export function useTransactions(limitCount = 100) {
  const [transactions, setTransactions] = useState<(Transaction | SolanaTransaction)[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `transactions-${limitCount}`;

  const fetchTransactions = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<(Transaction | SolanaTransaction)[]>(cacheKey);
      if (cached) {
        setTransactions(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const [txSnapshot, solanaTxSnapshot] = await Promise.all([
        getDocs(query(
          collection(db, 'transactions'),
          orderBy('timestamp', 'desc'),
          limit(limitCount)
        )),
        getDocs(query(
          collection(db, 'solana_transactions'),
          orderBy('timestamp', 'desc'),
          limit(limitCount)
        ))
      ]);

      const txData = txSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Transaction));
      const solanaTxData = solanaTxSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as SolanaTransaction));

      const combined = [...txData, ...solanaTxData].sort((a, b) => {
        const aTime = a.timestamp?.toMillis?.() || 0;
        const bTime = b.timestamp?.toMillis?.() || 0;
        return bTime - aTime;
      });

      const result = combined.slice(0, limitCount);
      setCache(cacheKey, result);
      setTransactions(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch transactions');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, limitCount]);

  useEffect(() => {
    fetchTransactions();
  }, [fetchTransactions]);

  const refetch = useCallback(() => fetchTransactions(true), [fetchTransactions]);

  return { transactions, loading, error, refetch };
}

export function usePaymentRequests(statusFilter?: string, limitCount = 100) {
  const [requests, setRequests] = useState<PaymentRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `requests-${statusFilter}-${limitCount}`;

  const fetchRequests = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<PaymentRequest[]>(cacheKey);
      if (cached) {
        setRequests(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const constraints: QueryConstraint[] = [
        orderBy('createdAt', 'desc'),
        limit(limitCount)
      ];

      if (statusFilter && statusFilter !== 'all') {
        constraints.unshift(where('status', '==', statusFilter));
      }

      const q = query(collection(db, 'payment_requests'), ...constraints);
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as PaymentRequest));

      setCache(cacheKey, data);
      setRequests(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch requests');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, statusFilter, limitCount]);

  useEffect(() => {
    fetchRequests();
  }, [fetchRequests]);

  const refetch = useCallback(() => fetchRequests(true), [fetchRequests]);

  return { requests, loading, error, refetch };
}

export function useAutoSwapLogs(limitCount = 100) {
  const [logs, setLogs] = useState<AutoSwapLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `autoswap-${limitCount}`;

  const fetchLogs = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<AutoSwapLog[]>(cacheKey);
      if (cached) {
        setLogs(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const q = query(
        collection(db, 'auto_swap_logs'),
        orderBy('timestamp', 'desc'),
        limit(limitCount)
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as AutoSwapLog));

      setCache(cacheKey, data);
      setLogs(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch auto-swap logs');
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

export function useDashboardStats() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = 'dashboard-stats';

  const fetchStats = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<DashboardStats>(cacheKey);
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

      const [usersCount, txCount, pendingRequestsCount, autoSwapsCount] = await Promise.all([
        getCountFromServer(collection(db, 'users')),
        getCountFromServer(query(
          collection(db, 'solana_transactions'),
          where('timestamp', '>=', twentyFourHoursAgo)
        )),
        getCountFromServer(query(
          collection(db, 'payment_requests'),
          where('status', '==', 'pending')
        )),
        getCountFromServer(query(
          collection(db, 'auto_swap_logs'),
          where('timestamp', '>=', twentyFourHoursAgo)
        ))
      ]);

      const data: DashboardStats = {
        totalUsers: usersCount.data().count,
        transactionsLast24h: txCount.data().count,
        pendingRequests: pendingRequestsCount.data().count,
        autoSwapsLast24h: autoSwapsCount.data().count,
      };

      setCache(cacheKey, data);
      setStats(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch stats');
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

export function useCoinbaseTransfers(typeFilter: 'all' | 'onramp' | 'offramp' = 'all', limitCount = 100) {
  const [transfers, setTransfers] = useState<(CoinbaseOnrampSession | CoinbaseOfframpSession)[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cacheKey = `coinbase-${typeFilter}-${limitCount}`;

  const fetchTransfers = useCallback(async (skipCache = false) => {
    if (!skipCache) {
      const cached = getCached<(CoinbaseOnrampSession | CoinbaseOfframpSession)[]>(cacheKey);
      if (cached) {
        setTransfers(cached);
        setLoading(false);
        return;
      }
    }

    setLoading(true);
    try {
      const results: (CoinbaseOnrampSession | CoinbaseOfframpSession)[] = [];

      const promises: Promise<void>[] = [];

      if (typeFilter === 'all' || typeFilter === 'onramp') {
        promises.push(
          getDocs(query(
            collection(db, 'coinbaseOnrampSessions'),
            orderBy('createdAt', 'desc'),
            limit(limitCount)
          )).then(snapshot => {
            const onrampData = snapshot.docs.map(doc => ({
              id: doc.id,
              ...doc.data(),
              _type: 'onramp' as const
            } as CoinbaseOnrampSession & { _type: 'onramp' }));
            results.push(...onrampData);
          })
        );
      }

      if (typeFilter === 'all' || typeFilter === 'offramp') {
        promises.push(
          getDocs(query(
            collection(db, 'coinbaseOfframpSessions'),
            orderBy('createdAt', 'desc'),
            limit(limitCount)
          )).then(snapshot => {
            const offrampData = snapshot.docs.map(doc => ({
              id: doc.id,
              ...doc.data(),
              _type: 'offramp' as const
            } as CoinbaseOfframpSession & { _type: 'offramp' }));
            results.push(...offrampData);
          })
        );
      }

      await Promise.all(promises);

      results.sort((a, b) => {
        const aTime = a.createdAt?.toMillis?.() || 0;
        const bTime = b.createdAt?.toMillis?.() || 0;
        return bTime - aTime;
      });

      const data = results.slice(0, limitCount);
      setCache(cacheKey, data);
      setTransfers(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch Coinbase transfers');
    } finally {
      setLoading(false);
    }
  }, [cacheKey, typeFilter, limitCount]);

  useEffect(() => {
    fetchTransfers();
  }, [fetchTransfers]);

  const refetch = useCallback(() => fetchTransfers(true), [fetchTransfers]);

  return { transfers, loading, error, refetch };
}

// Utility to clear all cache (useful for logout or manual refresh)
export function clearAllCache() {
  cache.clear();
}
