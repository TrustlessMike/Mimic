'use client';

import { useState, useEffect, useCallback } from 'react';

interface Stats {
  wallets: number;
  bets: number;
  markets: number;
  polymarketMatches: number;
  recent: {
    volume: number;
    yesCount: number;
    noCount: number;
  };
}

interface Bet {
  id: string;
  walletNickname: string;
  marketTitle: string;
  direction: string;
  amount: number;
  shares: number;
  avgPrice: number;
  timestamp: string;
}

export default function Dashboard() {
  const [apiKey, setApiKey] = useState('');
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [error, setError] = useState('');
  const [stats, setStats] = useState<Stats | null>(null);
  const [recentBets, setRecentBets] = useState<Bet[]>([]);
  const [loading, setLoading] = useState(false);

  const validateAndFetch = useCallback(async (key: string) => {
    setLoading(true);
    setError('');

    try {
      // Test the API key with stats endpoint
      const res = await fetch('/api/stats', {
        headers: { 'x-api-key': key },
      });

      if (res.status === 401) {
        setError('Invalid API key');
        localStorage.removeItem('dashboard_api_key');
        setIsAuthenticated(false);
        setLoading(false);
        return;
      }

      if (!res.ok) {
        throw new Error('Failed to fetch stats');
      }

      const statsData = await res.json();
      setStats(statsData);

      // Fetch recent bets
      const betsRes = await fetch('/api/bets?limit=10', {
        headers: { 'x-api-key': key },
      });
      if (betsRes.ok) {
        const betsData = await betsRes.json();
        setRecentBets(betsData.bets || []);
      }

      // Save valid key
      localStorage.setItem('dashboard_api_key', key);
      setIsAuthenticated(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Connection failed');
    } finally {
      setLoading(false);
    }
  }, []);

  // Check for saved API key on mount
  useEffect(() => {
    const savedKey = localStorage.getItem('dashboard_api_key');
    if (savedKey) {
      setApiKey(savedKey);
      validateAndFetch(savedKey);
    }
  }, [validateAndFetch]);

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    validateAndFetch(apiKey);
  };

  const handleLogout = () => {
    localStorage.removeItem('dashboard_api_key');
    setIsAuthenticated(false);
    setApiKey('');
    setStats(null);
    setRecentBets([]);
  };

  const refreshData = () => {
    validateAndFetch(apiKey);
  };

  // Login screen
  if (!isAuthenticated) {
    return (
      <main style={styles.container}>
        <div style={styles.loginCard}>
          <h1 style={styles.title}>Mimic Dashboard</h1>
          <p style={styles.subtitle}>Enter your API key to access the dashboard</p>

          <form onSubmit={handleLogin} style={styles.form}>
            <input
              type="password"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              placeholder="API Key"
              style={styles.input}
              autoFocus
            />
            <button type="submit" disabled={loading} style={styles.button}>
              {loading ? 'Verifying...' : 'Login'}
            </button>
          </form>

          {error && <p style={styles.error}>{error}</p>}
        </div>
      </main>
    );
  }

  // Dashboard
  return (
    <main style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Mimic Dashboard</h1>
        <div style={styles.headerActions}>
          <button onClick={refreshData} disabled={loading} style={styles.refreshBtn}>
            {loading ? 'Refreshing...' : 'Refresh'}
          </button>
          <button onClick={handleLogout} style={styles.logoutBtn}>
            Logout
          </button>
        </div>
      </div>

      {/* Stats Cards */}
      {stats && (
        <div style={styles.statsGrid}>
          <div style={styles.statCard}>
            <div style={styles.statValue}>{stats.wallets}</div>
            <div style={styles.statLabel}>Active Wallets</div>
          </div>
          <div style={styles.statCard}>
            <div style={styles.statValue}>{stats.bets.toLocaleString()}</div>
            <div style={styles.statLabel}>Total Bets</div>
          </div>
          <div style={styles.statCard}>
            <div style={styles.statValue}>{stats.markets}</div>
            <div style={styles.statLabel}>Markets</div>
          </div>
          <div style={styles.statCard}>
            <div style={styles.statValue}>{stats.polymarketMatches}</div>
            <div style={styles.statLabel}>Polymarket Matches</div>
          </div>
        </div>
      )}

      {/* Recent Activity */}
      {stats?.recent && (
        <div style={styles.recentCard}>
          <h2 style={styles.sectionTitle}>Recent Activity (Last 100 Bets)</h2>
          <div style={styles.recentStats}>
            <span>Volume: ${stats.recent.volume.toLocaleString(undefined, { maximumFractionDigits: 2 })}</span>
            <span style={{ color: '#22c55e' }}>YES: {stats.recent.yesCount}</span>
            <span style={{ color: '#ef4444' }}>NO: {stats.recent.noCount}</span>
          </div>
        </div>
      )}

      {/* Recent Bets Table */}
      <div style={styles.tableCard}>
        <h2 style={styles.sectionTitle}>Recent Bets</h2>
        <div style={styles.tableWrapper}>
          <table style={styles.table}>
            <thead>
              <tr>
                <th style={styles.th}>Wallet</th>
                <th style={styles.th}>Market</th>
                <th style={styles.th}>Direction</th>
                <th style={styles.th}>Amount</th>
                <th style={styles.th}>Shares</th>
                <th style={styles.th}>Avg Price</th>
                <th style={styles.th}>Time</th>
              </tr>
            </thead>
            <tbody>
              {recentBets.map((bet) => (
                <tr key={bet.id} style={styles.tr}>
                  <td style={styles.td}>{bet.walletNickname || 'Unknown'}</td>
                  <td style={{ ...styles.td, maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {bet.marketTitle}
                  </td>
                  <td style={{
                    ...styles.td,
                    color: bet.direction === 'YES' ? '#22c55e' : '#ef4444',
                    fontWeight: 'bold'
                  }}>
                    {bet.direction}
                  </td>
                  <td style={styles.td}>${bet.amount?.toFixed(2)}</td>
                  <td style={styles.td}>{bet.shares?.toFixed(2)}</td>
                  <td style={styles.td}>{(bet.avgPrice * 100)?.toFixed(1)}%</td>
                  <td style={styles.td}>
                    {bet.timestamp ? new Date(bet.timestamp).toLocaleString() : '-'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* API Endpoints */}
      <div style={styles.endpointsCard}>
        <h2 style={styles.sectionTitle}>API Endpoints</h2>
        <p style={{ color: '#9ca3af', marginBottom: '1rem' }}>
          All endpoints require the <code style={styles.code}>x-api-key</code> header
        </p>
        <ul style={styles.endpointList}>
          <li>/api/health - Health check (public)</li>
          <li>/api/stats - Overall statistics</li>
          <li>/api/wallets - Smart money wallets</li>
          <li>/api/bets - Recent prediction bets</li>
          <li>/api/markets - Jupiter markets</li>
          <li>/api/polymarket - Polymarket matches</li>
        </ul>
      </div>
    </main>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    minHeight: '100vh',
    backgroundColor: '#0f172a',
    color: '#f1f5f9',
    padding: '2rem',
    fontFamily: 'system-ui, -apple-system, sans-serif',
  },
  loginCard: {
    maxWidth: '400px',
    margin: '100px auto',
    padding: '2rem',
    backgroundColor: '#1e293b',
    borderRadius: '12px',
    textAlign: 'center',
  },
  title: {
    fontSize: '1.75rem',
    fontWeight: 'bold',
    marginBottom: '0.5rem',
  },
  subtitle: {
    color: '#94a3b8',
    marginBottom: '1.5rem',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '1rem',
  },
  input: {
    padding: '0.75rem 1rem',
    borderRadius: '8px',
    border: '1px solid #334155',
    backgroundColor: '#0f172a',
    color: '#f1f5f9',
    fontSize: '1rem',
  },
  button: {
    padding: '0.75rem 1rem',
    borderRadius: '8px',
    border: 'none',
    backgroundColor: '#3b82f6',
    color: 'white',
    fontSize: '1rem',
    cursor: 'pointer',
    fontWeight: '500',
  },
  error: {
    color: '#ef4444',
    marginTop: '1rem',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '2rem',
  },
  headerActions: {
    display: 'flex',
    gap: '0.5rem',
  },
  refreshBtn: {
    padding: '0.5rem 1rem',
    borderRadius: '6px',
    border: '1px solid #334155',
    backgroundColor: 'transparent',
    color: '#94a3b8',
    cursor: 'pointer',
  },
  logoutBtn: {
    padding: '0.5rem 1rem',
    borderRadius: '6px',
    border: 'none',
    backgroundColor: '#dc2626',
    color: 'white',
    cursor: 'pointer',
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
    gap: '1rem',
    marginBottom: '2rem',
  },
  statCard: {
    backgroundColor: '#1e293b',
    padding: '1.5rem',
    borderRadius: '12px',
    textAlign: 'center',
  },
  statValue: {
    fontSize: '2rem',
    fontWeight: 'bold',
    color: '#3b82f6',
  },
  statLabel: {
    color: '#94a3b8',
    marginTop: '0.5rem',
  },
  recentCard: {
    backgroundColor: '#1e293b',
    padding: '1.5rem',
    borderRadius: '12px',
    marginBottom: '2rem',
  },
  sectionTitle: {
    fontSize: '1.25rem',
    fontWeight: '600',
    marginBottom: '1rem',
  },
  recentStats: {
    display: 'flex',
    gap: '2rem',
    fontSize: '1.1rem',
  },
  tableCard: {
    backgroundColor: '#1e293b',
    padding: '1.5rem',
    borderRadius: '12px',
    marginBottom: '2rem',
  },
  tableWrapper: {
    overflowX: 'auto',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
  },
  th: {
    textAlign: 'left',
    padding: '0.75rem',
    borderBottom: '1px solid #334155',
    color: '#94a3b8',
    fontSize: '0.875rem',
    fontWeight: '500',
  },
  tr: {
    borderBottom: '1px solid #334155',
  },
  td: {
    padding: '0.75rem',
    fontSize: '0.875rem',
    whiteSpace: 'nowrap',
  },
  endpointsCard: {
    backgroundColor: '#1e293b',
    padding: '1.5rem',
    borderRadius: '12px',
  },
  code: {
    backgroundColor: '#334155',
    padding: '0.25rem 0.5rem',
    borderRadius: '4px',
    fontFamily: 'monospace',
  },
  endpointList: {
    listStyle: 'none',
    padding: 0,
    margin: 0,
    display: 'flex',
    flexDirection: 'column',
    gap: '0.5rem',
  },
};
