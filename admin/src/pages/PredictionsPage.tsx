import { useState, useMemo, memo } from 'react';
import { format } from 'date-fns';
import {
  useSmartMoneyWallets,
  usePredictionBets,
  usePredictionStats,
  useAddSmartMoneyWallet,
  useRemoveSmartMoneyWallet,
} from '../hooks/usePredictions';
import { StatCardSkeleton, TableRowSkeleton } from '../components/common/Skeleton';
import {
  TrendingUp,
  Wallet,
  Target,
  Clock,
  ExternalLink,
  Copy,
  Check,
  Plus,
  Trash2,
  X,
  RefreshCw,
  Search,
} from 'lucide-react';
import type { BetDirection, BetStatus } from '../types';

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

type FilterTab = 'all' | BetDirection | BetStatus;

export function PredictionsPage() {
  const { stats, loading: statsLoading, refetch: refetchStats } = usePredictionStats();
  const { wallets, loading: walletsLoading, refetch: refetchWallets } = useSmartMoneyWallets(100);
  const { bets, loading: betsLoading, refetch: refetchBets } = usePredictionBets(undefined, 100);
  const { addWallet, loading: addLoading, error: addError } = useAddSmartMoneyWallet();
  const { removeWallet, loading: removeLoading } = useRemoveSmartMoneyWallet();

  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [showAddModal, setShowAddModal] = useState(false);
  const [newWalletAddress, setNewWalletAddress] = useState('');
  const [newWalletNickname, setNewWalletNickname] = useState('');
  const [newWalletNotes, setNewWalletNotes] = useState('');
  const [walletSearch, setWalletSearch] = useState('');
  const [betFilter, setBetFilter] = useState<FilterTab>('all');

  const isLoading = statsLoading || walletsLoading || betsLoading;

  const filteredWallets = useMemo(() => {
    if (!walletSearch) return wallets;
    const lowerSearch = walletSearch.toLowerCase();
    return wallets.filter(w =>
      w.address?.toLowerCase().includes(lowerSearch) ||
      w.nickname?.toLowerCase().includes(lowerSearch)
    );
  }, [wallets, walletSearch]);

  const filteredBets = useMemo(() => {
    if (betFilter === 'all') return bets;
    // Check if it's a direction filter
    if (betFilter === 'YES' || betFilter === 'NO') {
      return bets.filter(b => b.direction === betFilter);
    }
    // It's a status filter
    return bets.filter(b => b.status === betFilter);
  }, [bets, betFilter]);

  const copyToClipboard = async (text: string, id: string) => {
    await navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleRefresh = () => {
    refetchStats();
    refetchWallets();
    refetchBets();
  };

  const handleAddWallet = async () => {
    if (!newWalletAddress.trim()) return;
    const success = await addWallet(newWalletAddress.trim(), newWalletNickname.trim() || undefined, newWalletNotes.trim() || undefined);
    if (success) {
      setShowAddModal(false);
      setNewWalletAddress('');
      setNewWalletNickname('');
      setNewWalletNotes('');
      refetchWallets();
      refetchStats();
    }
  };

  const handleRemoveWallet = async (address: string) => {
    if (!confirm('Are you sure you want to remove this wallet from the smart money list?')) return;
    const success = await removeWallet(address);
    if (success) {
      refetchWallets();
      refetchStats();
    }
  };

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-emerald-50">
            <TrendingUp className="w-6 h-6 text-emerald-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-content-primary">Prediction Markets</h1>
            <p className="text-sm text-content-tertiary">Monitor smart money bets and prediction activity</p>
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
              title="Smart Money Wallets"
              value={stats?.totalSmartMoneyWallets ?? 0}
              icon={Wallet}
              gradient="text-primary-600"
              iconBg="bg-primary-50"
            />
            <StatCard
              title="Total Bets"
              value={stats?.totalPredictionBets ?? 0}
              icon={Target}
              gradient="text-emerald-600"
              iconBg="bg-emerald-50"
            />
            <StatCard
              title="Active Bets"
              value={stats?.activeBets ?? 0}
              icon={TrendingUp}
              gradient="text-amber-600"
              iconBg="bg-amber-50"
            />
            <StatCard
              title="Bets (24h)"
              value={stats?.betsLast24h ?? 0}
              icon={Clock}
              gradient="text-cyan-600"
              iconBg="bg-cyan-50"
            />
          </>
        )}
      </div>

      {/* Smart Money Wallets */}
      <div className="glass-card p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-primary-50">
              <Wallet className="w-5 h-5 text-primary-600" />
            </div>
            <h2 className="text-lg font-semibold text-content-primary">Smart Money Wallets</h2>
          </div>
          <div className="flex items-center gap-3">
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
            <button onClick={() => setShowAddModal(true)} className="btn-primary gap-2">
              <Plus className="w-4 h-4" />
              Add Wallet
            </button>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>Nickname</th>
                <th>Address</th>
                <th>Win Rate</th>
                <th>Total Bets</th>
                <th>P&L</th>
                <th>Added</th>
                <th>Actions</th>
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
                    {walletSearch ? 'No wallets match your search' : 'No smart money wallets added yet'}
                  </td>
                </tr>
              ) : (
                filteredWallets.map((wallet) => (
                  <tr key={wallet.id}>
                    <td className="text-content-primary font-medium">{wallet.nickname || '-'}</td>
                    <td>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-content-secondary">
                          {wallet.address.slice(0, 4)}...{wallet.address.slice(-4)}
                        </span>
                        <button
                          onClick={() => copyToClipboard(wallet.address, wallet.id)}
                          className="p-1 rounded-lg hover:bg-surface-100 transition-colors"
                        >
                          {copiedId === wallet.id ? (
                            <Check className="w-3.5 h-3.5 text-emerald-600" />
                          ) : (
                            <Copy className="w-3.5 h-3.5 text-content-tertiary" />
                          )}
                        </button>
                        <a
                          href={`https://solscan.io/account/${wallet.address}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="p-1 rounded-lg hover:bg-surface-100 transition-colors"
                        >
                          <ExternalLink className="w-3.5 h-3.5 text-content-tertiary hover:text-primary-600" />
                        </a>
                      </div>
                    </td>
                    <td className="text-content-primary">{wallet.stats?.winRate ? `${(wallet.stats.winRate * 100).toFixed(1)}%` : '-'}</td>
                    <td className="text-content-primary">{wallet.stats?.totalBets ?? 0}</td>
                    <td className={wallet.stats?.totalPnl >= 0 ? 'text-emerald-600' : 'text-rose-600'}>
                      {wallet.stats?.totalPnl !== undefined ? `$${wallet.stats.totalPnl.toFixed(2)}` : '-'}
                    </td>
                    <td className="text-content-tertiary">
                      {wallet.addedAt?.toDate ? format(wallet.addedAt.toDate(), 'MMM d, yyyy') : '-'}
                    </td>
                    <td>
                      <button
                        onClick={() => handleRemoveWallet(wallet.address)}
                        disabled={removeLoading}
                        className="p-2 rounded-lg text-content-tertiary hover:text-rose-600 hover:bg-rose-50 transition-colors"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Prediction Bets Feed */}
      <div className="glass-card p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-emerald-50">
              <Target className="w-5 h-5 text-emerald-600" />
            </div>
            <h2 className="text-lg font-semibold text-content-primary">Prediction Bets</h2>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            {(['all', 'YES', 'NO', 'open', 'won', 'lost'] as FilterTab[]).map((tab) => (
              <button
                key={tab}
                onClick={() => setBetFilter(tab)}
                className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                  betFilter === tab
                    ? 'bg-primary-600 text-white'
                    : 'bg-surface-100 text-content-secondary hover:text-content-primary hover:bg-surface-200'
                }`}
              >
                {tab === 'all' ? 'All' : tab.charAt(0).toUpperCase() + tab.slice(1)}
              </button>
            ))}
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>Wallet</th>
                <th>Market</th>
                <th>Direction</th>
                <th>Amount</th>
                <th>Shares</th>
                <th>Avg Price</th>
                <th>Status</th>
                <th>P&L</th>
                <th>Time</th>
                <th>Tx</th>
              </tr>
            </thead>
            <tbody>
              {betsLoading ? (
                <>
                  <TableRowSkeleton cols={10} />
                  <TableRowSkeleton cols={10} />
                  <TableRowSkeleton cols={10} />
                </>
              ) : filteredBets.length === 0 ? (
                <tr>
                  <td colSpan={10} className="text-center py-8 text-content-tertiary">
                    No prediction bets found
                  </td>
                </tr>
              ) : (
                filteredBets.map((bet) => (
                  <tr key={bet.id}>
                    <td>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-content-secondary">
                          {bet.walletAddress.slice(0, 4)}...{bet.walletAddress.slice(-4)}
                        </span>
                        {bet.walletNickname && (
                          <span className="text-xs text-primary-600">({bet.walletNickname})</span>
                        )}
                      </div>
                    </td>
                    <td className="text-content-primary max-w-[200px] truncate" title={bet.marketTitle || bet.marketAddress}>
                      {bet.marketTitle || `${bet.marketAddress.slice(0, 8)}...`}
                    </td>
                    <td>
                      <span className={`badge ${bet.direction === 'YES' ? 'badge-success' : 'badge-error'}`}>
                        {bet.direction}
                      </span>
                    </td>
                    <td className="text-content-primary">${bet.amount?.toFixed(2) ?? '-'}</td>
                    <td className="text-content-secondary">{bet.shares?.toFixed(2) ?? '-'}</td>
                    <td className="text-content-secondary">{bet.avgPrice?.toFixed(3) ?? '-'}</td>
                    <td>
                      <span className={`badge ${
                        bet.status === 'open' ? 'badge-info' :
                        bet.status === 'won' ? 'badge-success' :
                        bet.status === 'lost' ? 'badge-error' : 'badge-neutral'
                      }`}>
                        {bet.status}
                      </span>
                    </td>
                    <td className={bet.pnl !== undefined ? (bet.pnl >= 0 ? 'text-emerald-600' : 'text-rose-600') : 'text-content-tertiary'}>
                      {bet.pnl !== undefined ? `$${bet.pnl.toFixed(2)}` : '-'}
                    </td>
                    <td className="text-content-tertiary">
                      {bet.timestamp?.toDate ? format(bet.timestamp.toDate(), 'MMM d, HH:mm') : '-'}
                    </td>
                    <td>
                      <a
                        href={`https://solscan.io/tx/${bet.signature}`}
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

      {/* Add Wallet Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/30 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="glass-card p-6 w-full max-w-md mx-4">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-semibold text-content-primary">Add Smart Money Wallet</h3>
              <button
                onClick={() => setShowAddModal(false)}
                className="p-2 rounded-lg hover:bg-surface-100 transition-colors"
              >
                <X className="w-5 h-5 text-content-tertiary" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-content-secondary mb-2">
                  Wallet Address *
                </label>
                <input
                  type="text"
                  value={newWalletAddress}
                  onChange={(e) => setNewWalletAddress(e.target.value)}
                  placeholder="Enter Solana wallet address"
                  className="w-full px-4 py-3 rounded-xl bg-surface-100 border border-surface-300 text-content-primary placeholder-content-muted focus:outline-none focus:border-primary-400 focus:ring-2 focus:ring-primary-100"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-content-secondary mb-2">
                  Nickname (optional)
                </label>
                <input
                  type="text"
                  value={newWalletNickname}
                  onChange={(e) => setNewWalletNickname(e.target.value)}
                  placeholder="e.g., Top Trader #1"
                  className="w-full px-4 py-3 rounded-xl bg-surface-100 border border-surface-300 text-content-primary placeholder-content-muted focus:outline-none focus:border-primary-400 focus:ring-2 focus:ring-primary-100"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-content-secondary mb-2">
                  Notes (optional)
                </label>
                <textarea
                  value={newWalletNotes}
                  onChange={(e) => setNewWalletNotes(e.target.value)}
                  placeholder="Add any notes about this wallet..."
                  rows={3}
                  className="w-full px-4 py-3 rounded-xl bg-surface-100 border border-surface-300 text-content-primary placeholder-content-muted focus:outline-none focus:border-primary-400 focus:ring-2 focus:ring-primary-100 resize-none"
                />
              </div>

              {addError && (
                <p className="text-sm text-rose-600">{addError}</p>
              )}

              <div className="flex gap-3 pt-2">
                <button
                  onClick={() => setShowAddModal(false)}
                  className="btn-secondary flex-1"
                >
                  Cancel
                </button>
                <button
                  onClick={handleAddWallet}
                  disabled={!newWalletAddress.trim() || addLoading}
                  className="btn-primary flex-1 gap-2"
                >
                  {addLoading ? (
                    <RefreshCw className="w-4 h-4 animate-spin" />
                  ) : (
                    <Plus className="w-4 h-4" />
                  )}
                  Add Wallet
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
