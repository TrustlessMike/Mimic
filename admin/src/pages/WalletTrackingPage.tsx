import { useState, useMemo, memo } from 'react';
import { format } from 'date-fns';
import {
  useTrackedWallets,
  useTrackedTrades,
  useCopyBots,
  useCopyTradeLogs,
  useWalletTrackingStats,
} from '../hooks/useWalletTracking';
import { StatCardSkeleton, TableRowSkeleton } from '../components/common/Skeleton';
import {
  Eye,
  Wallet,
  ArrowLeftRight,
  Bot,
  Activity,
  Clock,
  ExternalLink,
  Copy,
  Check,
  RefreshCw,
  Search,
  Shield,
  Flame,
  ChevronDown,
  ChevronUp,
} from 'lucide-react';
import type { TradeType } from '../types';

interface StatCardProps {
  title: string;
  value: number | string;
  icon: React.ElementType;
  gradient: string;
  iconBg: string;
}

const StatCard = memo(function StatCard({ title, value, icon: Icon, gradient, iconBg }: StatCardProps) {
  return (
    <div className="stats-card group">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm font-medium text-content-tertiary">{title}</p>
          <p className="mt-2 text-3xl font-bold text-content-primary">{value}</p>
        </div>
        <div className={`p-3 rounded-xl ${iconBg}`}>
          <Icon className={`w-6 h-6 ${gradient}`} />
        </div>
      </div>
    </div>
  );
});

type TradeFilterTab = 'all' | TradeType | 'safe' | 'degen';

export function WalletTrackingPage() {
  const { stats, loading: statsLoading, refetch: refetchStats } = useWalletTrackingStats();
  const { wallets, loading: walletsLoading, refetch: refetchWallets } = useTrackedWallets(100);
  const { trades, loading: tradesLoading, refetch: refetchTrades } = useTrackedTrades(undefined, 100);
  const { bots, loading: botsLoading, refetch: refetchBots } = useCopyBots(100);
  const { logs, loading: logsLoading, refetch: refetchLogs } = useCopyTradeLogs(50);

  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [walletSearch, setWalletSearch] = useState('');
  const [tradeFilter, setTradeFilter] = useState<TradeFilterTab>('all');
  const [showCopyLogs, setShowCopyLogs] = useState(false);

  const isLoading = statsLoading || walletsLoading || tradesLoading || botsLoading;

  const filteredWallets = useMemo(() => {
    if (!walletSearch) return wallets;
    const lowerSearch = walletSearch.toLowerCase();
    return wallets.filter(w =>
      w.walletAddress?.toLowerCase().includes(lowerSearch) ||
      w.nickname?.toLowerCase().includes(lowerSearch)
    );
  }, [wallets, walletSearch]);

  const filteredTrades = useMemo(() => {
    if (tradeFilter === 'all') return trades;
    if (tradeFilter === 'buy' || tradeFilter === 'sell') {
      return trades.filter(t => t.type === tradeFilter);
    }
    if (tradeFilter === 'safe') {
      return trades.filter(t => t.isSafeModeTrade);
    }
    if (tradeFilter === 'degen') {
      return trades.filter(t => !t.isSafeModeTrade);
    }
    return trades;
  }, [trades, tradeFilter]);

  const copyToClipboard = async (text: string, id: string) => {
    await navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleRefresh = () => {
    refetchStats();
    refetchWallets();
    refetchTrades();
    refetchBots();
    refetchLogs();
  };

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-primary-50">
            <Eye className="w-6 h-6 text-primary-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-content-primary">Wallet Tracking</h1>
            <p className="text-sm text-content-tertiary">Monitor tracked wallets, trades, and copy bots</p>
          </div>
        </div>
        <button onClick={handleRefresh} disabled={isLoading} className="btn-secondary gap-2">
          <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
          Refresh
        </button>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        {statsLoading ? (
          <>
            <StatCardSkeleton />
            <StatCardSkeleton />
            <StatCardSkeleton />
            <StatCardSkeleton />
          </>
        ) : (
          <>
            <StatCard
              title="Tracked Wallets"
              value={stats?.totalTrackedWallets ?? 0}
              icon={Wallet}
              gradient="text-primary-600"
              iconBg="bg-primary-50"
            />
            <StatCard
              title="Total Trades"
              value={stats?.totalTrackedTrades ?? 0}
              icon={ArrowLeftRight}
              gradient="text-emerald-600"
              iconBg="bg-emerald-50"
            />
            <StatCard
              title="Active Copy Bots"
              value={stats?.activeCopyBots ?? 0}
              icon={Bot}
              gradient="text-amber-600"
              iconBg="bg-amber-50"
            />
            <StatCard
              title="Copy Trades (24h)"
              value={stats?.copyTradesLast24h ?? 0}
              icon={Clock}
              gradient="text-cyan-600"
              iconBg="bg-cyan-50"
            />
          </>
        )}
      </div>

      {/* Tracked Wallets */}
      <div className="glass-card p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-primary-50">
              <Wallet className="w-5 h-5 text-primary-600" />
            </div>
            <h2 className="text-lg font-semibold text-content-primary">Tracked Wallets</h2>
            <span className="text-sm text-content-tertiary">({wallets.length})</span>
          </div>
          <div className="relative w-full sm:w-64">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-content-muted" />
            <input
              type="text"
              value={walletSearch}
              onChange={(e) => setWalletSearch(e.target.value)}
              placeholder="Search wallets..."
              className="search-input"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>User ID</th>
                <th>Wallet Address</th>
                <th>Nickname</th>
                <th>Total Trades</th>
                <th>Win Rate</th>
                <th>P&L</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {walletsLoading ? (
                <>
                  <TableRowSkeleton cols={7} />
                  <TableRowSkeleton cols={7} />
                  <TableRowSkeleton cols={7} />
                </>
              ) : filteredWallets.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-8 text-content-tertiary">
                    {walletSearch ? 'No wallets match your search' : 'No tracked wallets yet'}
                  </td>
                </tr>
              ) : (
                filteredWallets.map((wallet) => (
                  <tr key={wallet.id}>
                    <td className="font-mono text-content-secondary text-xs">
                      {wallet.oduserId?.slice(0, 8)}...
                    </td>
                    <td>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-content-secondary">
                          {wallet.walletAddress.slice(0, 4)}...{wallet.walletAddress.slice(-4)}
                        </span>
                        <button
                          onClick={() => copyToClipboard(wallet.walletAddress, wallet.id)}
                          className="p-1 rounded-lg hover:bg-surface-100 transition-colors"
                        >
                          {copiedId === wallet.id ? (
                            <Check className="w-3.5 h-3.5 text-emerald-600" />
                          ) : (
                            <Copy className="w-3.5 h-3.5 text-content-tertiary" />
                          )}
                        </button>
                        <a
                          href={`https://solscan.io/account/${wallet.walletAddress}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="p-1 rounded-lg hover:bg-surface-100 transition-colors"
                        >
                          <ExternalLink className="w-3.5 h-3.5 text-content-tertiary hover:text-primary-600" />
                        </a>
                      </div>
                    </td>
                    <td className="text-content-primary">{wallet.nickname || '-'}</td>
                    <td className="text-content-primary">{wallet.stats?.totalTrades ?? 0}</td>
                    <td className="text-content-primary">{wallet.stats?.winRate ? `${(wallet.stats.winRate * 100).toFixed(1)}%` : '-'}</td>
                    <td className={wallet.stats?.pnl !== undefined ? (wallet.stats.pnl >= 0 ? 'text-emerald-600' : 'text-rose-600') : 'text-content-tertiary'}>
                      {wallet.stats?.pnl !== undefined ? `$${wallet.stats.pnl.toFixed(2)}` : '-'}
                    </td>
                    <td className="text-content-tertiary">
                      {wallet.createdAt?.toDate ? format(wallet.createdAt.toDate(), 'MMM d, yyyy') : '-'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Tracked Trades Feed */}
      <div className="glass-card p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-emerald-50">
              <Activity className="w-5 h-5 text-emerald-600" />
            </div>
            <h2 className="text-lg font-semibold text-content-primary">Tracked Trades</h2>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            {(['all', 'buy', 'sell', 'safe', 'degen'] as TradeFilterTab[]).map((tab) => (
              <button
                key={tab}
                onClick={() => setTradeFilter(tab)}
                className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors flex items-center gap-1 ${
                  tradeFilter === tab
                    ? 'bg-primary-600 text-white'
                    : 'bg-surface-100 text-content-secondary hover:text-content-primary hover:bg-surface-200'
                }`}
              >
                {tab === 'safe' && <Shield className="w-3.5 h-3.5" />}
                {tab === 'degen' && <Flame className="w-3.5 h-3.5" />}
                {tab.charAt(0).toUpperCase() + tab.slice(1)}
              </button>
            ))}
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>Wallet</th>
                <th>Type</th>
                <th>Input</th>
                <th>Output</th>
                <th>Mode</th>
                <th>Time</th>
                <th>Tx</th>
              </tr>
            </thead>
            <tbody>
              {tradesLoading ? (
                <>
                  <TableRowSkeleton cols={7} />
                  <TableRowSkeleton cols={7} />
                  <TableRowSkeleton cols={7} />
                </>
              ) : filteredTrades.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-8 text-content-tertiary">
                    No tracked trades found
                  </td>
                </tr>
              ) : (
                filteredTrades.map((trade) => (
                  <tr key={trade.id}>
                    <td>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-content-secondary">
                          {trade.walletAddress.slice(0, 4)}...{trade.walletAddress.slice(-4)}
                        </span>
                        {trade.walletNickname && (
                          <span className="text-xs text-primary-600">({trade.walletNickname})</span>
                        )}
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${trade.type === 'buy' ? 'badge-success' : 'badge-warning'}`}>
                        {trade.type}
                      </span>
                    </td>
                    <td className="text-content-primary">
                      <div className="flex flex-col">
                        <span>{trade.inputToken?.amount?.toFixed(4)} {trade.inputToken?.symbol}</span>
                        {trade.inputToken?.usdValue && (
                          <span className="text-xs text-content-tertiary">${trade.inputToken.usdValue.toFixed(2)}</span>
                        )}
                      </div>
                    </td>
                    <td className="text-content-primary">
                      <div className="flex flex-col">
                        <span>{trade.outputToken?.amount?.toFixed(4)} {trade.outputToken?.symbol}</span>
                        {trade.outputToken?.usdValue && (
                          <span className="text-xs text-content-tertiary">${trade.outputToken.usdValue.toFixed(2)}</span>
                        )}
                      </div>
                    </td>
                    <td>
                      {trade.isSafeModeTrade ? (
                        <div className="flex items-center gap-1 text-emerald-600">
                          <Shield className="w-4 h-4" />
                          <span className="text-xs">Safe</span>
                        </div>
                      ) : (
                        <div className="flex items-center gap-1 text-amber-600">
                          <Flame className="w-4 h-4" />
                          <span className="text-xs">Degen</span>
                        </div>
                      )}
                    </td>
                    <td className="text-content-tertiary">
                      {trade.timestamp?.toDate ? format(trade.timestamp.toDate(), 'MMM d, HH:mm') : '-'}
                    </td>
                    <td>
                      <a
                        href={`https://solscan.io/tx/${trade.signature}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="p-1 rounded-lg hover:bg-surface-100 transition-colors inline-flex"
                      >
                        <ExternalLink className="w-4 h-4 text-content-tertiary hover:text-primary-600" />
                      </a>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Copy Bots */}
      <div className="glass-card p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-amber-50">
              <Bot className="w-5 h-5 text-amber-600" />
            </div>
            <h2 className="text-lg font-semibold text-content-primary">Copy Bots</h2>
            <span className="text-sm text-content-tertiary">({bots.length})</span>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>User ID</th>
                <th>Source Wallet</th>
                <th>Status</th>
                <th>Max Size</th>
                <th>Slippage</th>
                <th>Mode</th>
                <th>Copied</th>
                <th>Success Rate</th>
                <th>Volume</th>
              </tr>
            </thead>
            <tbody>
              {botsLoading ? (
                <>
                  <TableRowSkeleton cols={9} />
                  <TableRowSkeleton cols={9} />
                </>
              ) : bots.length === 0 ? (
                <tr>
                  <td colSpan={9} className="text-center py-8 text-content-tertiary">
                    No copy bots configured
                  </td>
                </tr>
              ) : (
                bots.map((bot) => (
                  <tr key={bot.id}>
                    <td className="font-mono text-content-secondary text-xs">
                      {bot.userId?.slice(0, 8)}...
                    </td>
                    <td>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-content-secondary">
                          {bot.sourceWalletAddress.slice(0, 4)}...{bot.sourceWalletAddress.slice(-4)}
                        </span>
                        {bot.sourceNickname && (
                          <span className="text-xs text-primary-600">({bot.sourceNickname})</span>
                        )}
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${bot.isActive ? 'badge-success' : 'badge-neutral'}`}>
                        {bot.isActive ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td className="text-content-primary">${bot.maxTradeSize}</td>
                    <td className="text-content-primary">{(bot.slippageBps / 100).toFixed(1)}%</td>
                    <td>
                      {bot.degenModeEnabled ? (
                        <div className="flex items-center gap-1 text-amber-600">
                          <Flame className="w-4 h-4" />
                          <span className="text-xs">Degen</span>
                        </div>
                      ) : (
                        <div className="flex items-center gap-1 text-emerald-600">
                          <Shield className="w-4 h-4" />
                          <span className="text-xs">Safe</span>
                        </div>
                      )}
                    </td>
                    <td className="text-content-primary">{bot.stats?.totalCopied ?? 0}</td>
                    <td className="text-content-primary">{bot.stats?.successRate ? `${(bot.stats.successRate * 100).toFixed(1)}%` : '-'}</td>
                    <td className="text-content-primary">${bot.stats?.totalVolume?.toFixed(2) ?? '0'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Copy Trade Logs (Collapsible) */}
      <div className="glass-card p-6">
        <button
          onClick={() => setShowCopyLogs(!showCopyLogs)}
          className="w-full flex items-center justify-between"
        >
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-cyan-50">
              <Activity className="w-5 h-5 text-cyan-600" />
            </div>
            <h2 className="text-lg font-semibold text-content-primary">Copy Trade Logs</h2>
            <span className="text-sm text-content-tertiary">({logs.length})</span>
          </div>
          {showCopyLogs ? (
            <ChevronUp className="w-5 h-5 text-content-tertiary" />
          ) : (
            <ChevronDown className="w-5 h-5 text-content-tertiary" />
          )}
        </button>

        {showCopyLogs && (
          <div className="mt-6 overflow-x-auto">
            <table className="data-table">
              <thead>
                <tr>
                  <th>User ID</th>
                  <th>Trade</th>
                  <th>Amount</th>
                  <th>Expected</th>
                  <th>Fee</th>
                  <th>Mode</th>
                  <th>Status</th>
                  <th>Time</th>
                  <th>Tx</th>
                </tr>
              </thead>
              <tbody>
                {logsLoading ? (
                  <>
                    <TableRowSkeleton cols={9} />
                    <TableRowSkeleton cols={9} />
                  </>
                ) : logs.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="text-center py-8 text-content-tertiary">
                      No copy trade logs yet
                    </td>
                  </tr>
                ) : (
                  logs.map((log) => (
                    <tr key={log.id}>
                      <td className="font-mono text-content-secondary text-xs">
                        {log.oduserId?.slice(0, 8)}...
                      </td>
                      <td className="font-mono text-content-secondary text-xs">
                        {log.originalTradeId?.slice(0, 8)}...
                      </td>
                      <td className="text-content-primary">{log.inputAmount}</td>
                      <td className="text-content-primary">{log.expectedOutput}</td>
                      <td className="text-content-tertiary">{(log.platformFeeBps / 100).toFixed(2)}%</td>
                      <td>
                        {log.degenMode ? (
                          <Flame className="w-4 h-4 text-amber-600" />
                        ) : (
                          <Shield className="w-4 h-4 text-emerald-600" />
                        )}
                      </td>
                      <td>
                        <span className={`badge ${
                          log.status === 'confirmed' ? 'badge-success' :
                          log.status === 'failed' ? 'badge-error' :
                          log.status === 'submitted' ? 'badge-warning' : 'badge-info'
                        }`}>
                          {log.status}
                        </span>
                      </td>
                      <td className="text-content-tertiary">
                        {log.createdAt?.toDate ? format(log.createdAt.toDate(), 'MMM d, HH:mm') : '-'}
                      </td>
                      <td>
                        {log.signature && (
                          <a
                            href={`https://solscan.io/tx/${log.signature}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="p-1 rounded-lg hover:bg-surface-100 transition-colors inline-flex"
                          >
                            <ExternalLink className="w-4 h-4 text-content-tertiary hover:text-primary-600" />
                          </a>
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
