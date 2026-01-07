import { memo, useCallback } from 'react';
import { Users, ArrowLeftRight, FileText, RefreshCw, TrendingUp, Activity, DollarSign, Wallet } from 'lucide-react';
import { useDashboardStats, useTransactions, usePaymentRequests, useCoinbaseTransfers } from '../hooks/useFirestore';
import { StatCardSkeleton, ListItemSkeleton, TableRowSkeleton } from '../components/common/Skeleton';
import { format } from 'date-fns';
import type { Transaction, SolanaTransaction } from '../types';

function isTransaction(tx: Transaction | SolanaTransaction): tx is Transaction {
  return 'userId' in tx;
}

interface StatCardProps {
  title: string;
  value: number | string;
  icon: React.ElementType;
  trend?: string;
  gradient: string;
  iconBg: string;
}

const StatCard = memo(function StatCard({ title, value, icon: Icon, trend, gradient, iconBg }: StatCardProps) {
  return (
    <div className="stats-card group">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm font-medium text-dark-400">{title}</p>
          <p className="mt-2 text-3xl font-bold text-white">{value}</p>
          {trend && (
            <p className="mt-2 flex items-center gap-1 text-sm text-accent-emerald">
              <TrendingUp className="w-4 h-4" />
              {trend}
            </p>
          )}
        </div>
        <div className={`p-3 rounded-xl ${iconBg}`}>
          <Icon className={`w-6 h-6 ${gradient}`} />
        </div>
      </div>
    </div>
  );
});

export function DashboardPage() {
  const { stats, loading: statsLoading, refetch: refetchStats } = useDashboardStats();
  const { transactions, loading: txLoading, refetch: refetchTx } = useTransactions(5);
  const { requests, loading: reqLoading, refetch: refetchReq } = usePaymentRequests('pending', 5);
  const { transfers, loading: transfersLoading, refetch: refetchTransfers } = useCoinbaseTransfers('all', 5);

  const isLoading = statsLoading || txLoading || reqLoading || transfersLoading;

  const handleRefresh = useCallback(() => {
    refetchStats();
    refetchTx();
    refetchReq();
    refetchTransfers();
  }, [refetchStats, refetchTx, refetchReq, refetchTransfers]);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">Dashboard</h1>
          <p className="mt-1 text-dark-400">Welcome back! Here's what's happening with Wickett.</p>
        </div>
        <button
          onClick={handleRefresh}
          disabled={isLoading}
          className="btn-secondary gap-2"
        >
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
              title="Total Users"
              value={stats?.totalUsers ?? 0}
              icon={Users}
              gradient="text-brand-400"
              iconBg="bg-brand-500/10"
            />
            <StatCard
              title="Transactions (24h)"
              value={stats?.transactionsLast24h ?? 0}
              icon={ArrowLeftRight}
              gradient="text-accent-emerald"
              iconBg="bg-accent-emerald/10"
            />
            <StatCard
              title="Pending Requests"
              value={stats?.pendingRequests ?? 0}
              icon={FileText}
              gradient="text-accent-amber"
              iconBg="bg-accent-amber/10"
            />
            <StatCard
              title="Auto-Swaps (24h)"
              value={stats?.autoSwapsLast24h ?? 0}
              icon={RefreshCw}
              gradient="text-accent-cyan"
              iconBg="bg-accent-cyan/10"
            />
          </>
        )}
      </div>

      {/* Two column layout */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Transactions */}
        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-accent-emerald/10">
                <Activity className="w-5 h-5 text-accent-emerald" />
              </div>
              <h2 className="text-lg font-semibold text-white">Recent Transactions</h2>
            </div>
            <a href="/transactions" className="text-sm text-brand-400 hover:text-brand-300 transition-colors">
              View all
            </a>
          </div>

          <div className="space-y-4">
            {txLoading ? (
              <>
                <ListItemSkeleton />
                <ListItemSkeleton />
                <ListItemSkeleton />
              </>
            ) : transactions.length === 0 ? (
              <p className="text-center py-8 text-dark-400">No recent transactions</p>
            ) : (
              transactions.map((tx) => {
                const type = isTransaction(tx) ? tx.type : tx.transaction_type;
                const amount = isTransaction(tx) ? tx.amount : (tx.amount_usd ?? tx.amount);

                return (
                  <div key={tx.id} className="flex items-center justify-between p-3 rounded-xl bg-dark-800/50 hover:bg-dark-700/50 transition-colors">
                    <div className="flex items-center gap-3">
                      <div className={`p-2 rounded-lg ${
                        tx.status === 'success' ? 'bg-accent-emerald/10' :
                        tx.status === 'failed' ? 'bg-accent-rose/10' : 'bg-accent-amber/10'
                      }`}>
                        <ArrowLeftRight className={`w-4 h-4 ${
                          tx.status === 'success' ? 'text-accent-emerald' :
                          tx.status === 'failed' ? 'text-accent-rose' : 'text-accent-amber'
                        }`} />
                      </div>
                      <div>
                        <p className="text-sm font-medium text-white capitalize">{type || 'Transaction'}</p>
                        <p className="text-xs text-dark-400">
                          {tx.timestamp?.toDate ? format(tx.timestamp.toDate(), 'MMM d, HH:mm') : '-'}
                        </p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-medium text-white">
                        {amount !== undefined ? (isTransaction(tx) ? amount.toLocaleString() : `$${Number(amount).toFixed(2)}`) : '-'}
                      </p>
                      <span className={`badge ${
                        tx.status === 'success' ? 'badge-success' :
                        tx.status === 'failed' ? 'badge-error' : 'badge-warning'
                      }`}>
                        {tx.status}
                      </span>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Pending Payment Requests */}
        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-accent-amber/10">
                <FileText className="w-5 h-5 text-accent-amber" />
              </div>
              <h2 className="text-lg font-semibold text-white">Pending Requests</h2>
            </div>
            <a href="/requests" className="text-sm text-brand-400 hover:text-brand-300 transition-colors">
              View all
            </a>
          </div>

          <div className="space-y-4">
            {reqLoading ? (
              <>
                <ListItemSkeleton />
                <ListItemSkeleton />
                <ListItemSkeleton />
              </>
            ) : requests.length === 0 ? (
              <p className="text-center py-8 text-dark-400">No pending requests</p>
            ) : (
              requests.map((req) => (
                <div key={req.id} className="flex items-center justify-between p-3 rounded-xl bg-dark-800/50 hover:bg-dark-700/50 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-full bg-gradient-to-br from-brand-400 to-accent-cyan flex items-center justify-center">
                      <span className="text-xs font-bold text-white">
                        {(req.requesterName || 'U').charAt(0).toUpperCase()}
                      </span>
                    </div>
                    <div>
                      <p className="text-sm font-medium text-white">{req.requesterName || 'Unknown'}</p>
                      <p className="text-xs text-dark-400">
                        {req.createdAt?.toDate ? format(req.createdAt.toDate(), 'MMM d, HH:mm') : '-'}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium text-white">
                      {req.currency ? `${req.currency} ` : ''}{req.amount.toLocaleString()}
                    </p>
                    <span className="badge badge-warning">pending</span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Coinbase Transfers */}
      <div className="glass-card p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-brand-500/10">
              <Wallet className="w-5 h-5 text-brand-400" />
            </div>
            <h2 className="text-lg font-semibold text-white">Recent Coinbase Transfers</h2>
          </div>
          <a href="/coinbase" className="text-sm text-brand-400 hover:text-brand-300 transition-colors">
            View all
          </a>
        </div>

        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>Type</th>
                <th>Amount</th>
                <th>Status</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              {transfersLoading ? (
                <>
                  <TableRowSkeleton cols={4} />
                  <TableRowSkeleton cols={4} />
                  <TableRowSkeleton cols={4} />
                </>
              ) : transfers.length === 0 ? (
                <tr>
                  <td colSpan={4} className="text-center py-8 text-dark-400">No recent transfers</td>
                </tr>
              ) : (
                transfers.map((transfer) => {
                  const isOnramp = '_type' in transfer && transfer._type === 'onramp';
                  return (
                    <tr key={transfer.id}>
                      <td>
                        <div className="flex items-center gap-2">
                          <div className={`p-1.5 rounded-lg ${isOnramp ? 'bg-accent-emerald/10' : 'bg-accent-amber/10'}`}>
                            <DollarSign className={`w-4 h-4 ${isOnramp ? 'text-accent-emerald' : 'text-accent-amber'}`} />
                          </div>
                          <span className="text-white font-medium">{isOnramp ? 'Buy' : 'Sell'}</span>
                        </div>
                      </td>
                      <td className="text-white">
                        {transfer.fiatAmount ? `$${transfer.fiatAmount.toLocaleString()}` : '-'} {transfer.fiatCurrency}
                      </td>
                      <td>
                        <span className={`badge ${
                          transfer.status === 'completed' ? 'badge-success' :
                          transfer.status === 'failed' ? 'badge-error' :
                          transfer.status === 'pending' ? 'badge-warning' : 'badge-neutral'
                        }`}>
                          {transfer.status}
                        </span>
                      </td>
                      <td className="text-dark-400">
                        {transfer.createdAt?.toDate ? format(transfer.createdAt.toDate(), 'MMM d, HH:mm') : '-'}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
