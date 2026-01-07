import { memo, useCallback } from 'react';
import { RefreshCw, TrendingUp, Target, Eye, Shield, Flame, Wifi, WifiOff, Zap, Users, Copy, ArrowLeftRight } from 'lucide-react';
import { usePredictionStats, usePredictionBets } from '../hooks/usePredictions';
import { useWalletTrackingStats, useTrackedTrades, useRealtimeTrackerStatus, useCopyBots } from '../hooks/useWalletTracking';
import { StatCardSkeleton, ListItemSkeleton } from '../components/common/Skeleton';
import { format } from 'date-fns';

interface StatCardProps {
  title: string;
  value: number | string;
  icon: React.ElementType;
  trend?: string;
  iconColor: string;
  iconBg: string;
}

const StatCard = memo(function StatCard({ title, value, icon: Icon, trend, iconColor, iconBg }: StatCardProps) {
  return (
    <div className="stats-card group">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm font-medium text-content-tertiary">{title}</p>
          <p className="mt-2 text-3xl font-bold text-content-primary">{value}</p>
          {trend && (
            <p className="mt-2 flex items-center gap-1 text-sm text-emerald-600">
              <TrendingUp className="w-4 h-4" />
              {trend}
            </p>
          )}
        </div>
        <div className={`p-3 rounded-xl ${iconBg}`}>
          <Icon className={`w-6 h-6 ${iconColor}`} />
        </div>
      </div>
    </div>
  );
});

export function DashboardPage() {
  const { stats: predictionStats, loading: predictionStatsLoading, refetch: refetchPredictionStats } = usePredictionStats();
  const { bets: recentBets, loading: betsLoading, refetch: refetchBets } = usePredictionBets(undefined, 5);
  const { stats: trackingStats, loading: trackingStatsLoading, refetch: refetchTrackingStats } = useWalletTrackingStats();
  const { trades: recentTrades, loading: tradesLoading, refetch: refetchTrades } = useTrackedTrades(undefined, 5);
  const { bots: copyBots, loading: botsLoading, refetch: refetchBots } = useCopyBots(5);
  const { trackerStatus, loading: trackerLoading, refetch: refetchTracker } = useRealtimeTrackerStatus();

  const isLoading = predictionStatsLoading || trackingStatsLoading || botsLoading;

  const handleRefresh = useCallback(() => {
    refetchPredictionStats();
    refetchBets();
    refetchTrackingStats();
    refetchTrades();
    refetchBots();
    refetchTracker();
  }, [refetchPredictionStats, refetchBets, refetchTrackingStats, refetchTrades, refetchBots, refetchTracker]);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-content-primary">Dashboard</h1>
          <p className="mt-1 text-content-tertiary">Track smart money wallets and copy their trades.</p>
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

      {/* Real-Time Tracker Status */}
      <div className="glass-card p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className={`p-2 rounded-lg ${trackerStatus?.connected ? 'bg-emerald-50' : 'bg-rose-50'}`}>
              {trackerStatus?.connected ? (
                <Wifi className="w-5 h-5 text-emerald-600" />
              ) : (
                <WifiOff className="w-5 h-5 text-rose-600" />
              )}
            </div>
            <div>
              <h3 className="text-sm font-medium text-content-primary">Real-Time Tracker</h3>
              <p className="text-xs text-content-tertiary">
                {trackerLoading ? 'Checking...' : trackerStatus?.connected ? 'WebSocket Connected' : 'Disconnected'}
              </p>
            </div>
          </div>
          <div className="flex items-center gap-6">
            <div className="text-center">
              <p className="text-lg font-bold text-content-primary">{trackerStatus?.walletsTracked ?? '-'}</p>
              <p className="text-xs text-content-tertiary">Wallets</p>
            </div>
            <div className="text-center">
              <p className="text-lg font-bold text-content-primary">{trackerStatus?.txProcessed ?? '-'}</p>
              <p className="text-xs text-content-tertiary">TX Processed</p>
            </div>
            <div className="text-center">
              <p className="text-lg font-bold text-content-primary">{trackerStatus?.betsFound ?? '-'}</p>
              <p className="text-xs text-content-tertiary">Bets Found</p>
            </div>
            <div className="text-center">
              <p className="text-lg font-bold text-content-primary">
                {trackerStatus?.uptime ? `${Math.floor(trackerStatus.uptime / 60)}m` : '-'}
              </p>
              <p className="text-xs text-content-tertiary">Uptime</p>
            </div>
            <div className={`flex items-center gap-1 px-3 py-1 rounded-full ${
              trackerStatus?.connected ? 'bg-emerald-50 text-emerald-600' : 'bg-rose-50 text-rose-600'
            }`}>
              <Zap className="w-3 h-3" />
              <span className="text-xs font-medium">~500ms latency</span>
            </div>
          </div>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        {(predictionStatsLoading || trackingStatsLoading) ? (
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
              value={trackingStats?.totalTrackedWallets ?? 0}
              icon={Eye}
              iconColor="text-primary-600"
              iconBg="bg-primary-50"
            />
            <StatCard
              title="Prediction Bets"
              value={predictionStats?.totalPredictionBets ?? 0}
              icon={Target}
              iconColor="text-rose-600"
              iconBg="bg-rose-50"
            />
            <StatCard
              title="Active Copy Bots"
              value={trackingStats?.activeCopyBots ?? 0}
              icon={Copy}
              iconColor="text-cyan-600"
              iconBg="bg-cyan-50"
            />
            <StatCard
              title="Copy Trades (24h)"
              value={trackingStats?.copyTradesLast24h ?? 0}
              icon={ArrowLeftRight}
              iconColor="text-emerald-600"
              iconBg="bg-emerald-50"
            />
          </>
        )}
      </div>

      {/* Two column layout for Predictions and Wallet Tracking */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Prediction Bets */}
        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-rose-50">
                <Target className="w-5 h-5 text-rose-600" />
              </div>
              <h2 className="text-lg font-semibold text-content-primary">Recent Smart Money Bets</h2>
            </div>
            <a href="/predictions" className="text-sm text-primary-600 hover:text-primary-700 transition-colors">
              View all
            </a>
          </div>

          <div className="space-y-3">
            {betsLoading ? (
              <>
                <ListItemSkeleton />
                <ListItemSkeleton />
                <ListItemSkeleton />
              </>
            ) : recentBets.length === 0 ? (
              <p className="text-center py-8 text-content-tertiary">No recent prediction bets</p>
            ) : (
              recentBets.map((bet) => (
                <div key={bet.id} className="flex items-center justify-between p-3 rounded-xl bg-surface-100 hover:bg-surface-200 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className={`p-2 rounded-lg ${bet.direction === 'YES' ? 'bg-emerald-50' : 'bg-rose-50'}`}>
                      <TrendingUp className={`w-4 h-4 ${bet.direction === 'YES' ? 'text-emerald-600' : 'text-rose-600'}`} />
                    </div>
                    <div>
                      <p className="text-sm font-medium text-content-primary">
                        {bet.walletNickname || `${bet.walletAddress.slice(0, 4)}...${bet.walletAddress.slice(-4)}`}
                      </p>
                      <p className="text-xs text-content-tertiary">
                        {bet.timestamp?.toDate ? format(bet.timestamp.toDate(), 'MMM d, HH:mm') : '-'}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium text-content-primary">${bet.amount?.toFixed(2) ?? '-'}</p>
                    <span className={`badge ${bet.direction === 'YES' ? 'badge-success' : 'badge-error'}`}>
                      {bet.direction}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Recent Tracked Trades */}
        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary-50">
                <Eye className="w-5 h-5 text-primary-600" />
              </div>
              <h2 className="text-lg font-semibold text-content-primary">Recent Tracked Trades</h2>
            </div>
            <a href="/wallet-tracking" className="text-sm text-primary-600 hover:text-primary-700 transition-colors">
              View all
            </a>
          </div>

          <div className="space-y-3">
            {tradesLoading ? (
              <>
                <ListItemSkeleton />
                <ListItemSkeleton />
                <ListItemSkeleton />
              </>
            ) : recentTrades.length === 0 ? (
              <p className="text-center py-8 text-content-tertiary">No recent tracked trades</p>
            ) : (
              recentTrades.map((trade) => (
                <div key={trade.id} className="flex items-center justify-between p-3 rounded-xl bg-surface-100 hover:bg-surface-200 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className={`p-2 rounded-lg ${trade.type === 'buy' ? 'bg-emerald-50' : 'bg-amber-50'}`}>
                      <ArrowLeftRight className={`w-4 h-4 ${trade.type === 'buy' ? 'text-emerald-600' : 'text-amber-600'}`} />
                    </div>
                    <div>
                      <p className="text-sm font-medium text-content-primary">
                        {trade.walletNickname || `${trade.walletAddress.slice(0, 4)}...${trade.walletAddress.slice(-4)}`}
                      </p>
                      <p className="text-xs text-content-tertiary">
                        {trade.timestamp?.toDate ? format(trade.timestamp.toDate(), 'MMM d, HH:mm') : '-'}
                      </p>
                    </div>
                  </div>
                  <div className="text-right flex items-center gap-2">
                    <div>
                      <p className="text-sm font-medium text-content-primary">
                        {trade.inputToken?.symbol} → {trade.outputToken?.symbol}
                      </p>
                      <span className={`badge ${trade.type === 'buy' ? 'badge-success' : 'badge-warning'}`}>
                        {trade.type}
                      </span>
                    </div>
                    {trade.isSafeModeTrade ? (
                      <Shield className="w-4 h-4 text-emerald-600" />
                    ) : (
                      <Flame className="w-4 h-4 text-amber-600" />
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Active Copy Bots */}
      <div className="glass-card p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-cyan-50">
              <Copy className="w-5 h-5 text-cyan-600" />
            </div>
            <h2 className="text-lg font-semibold text-content-primary">Active Copy Bots</h2>
          </div>
          <a href="/wallet-tracking" className="text-sm text-primary-600 hover:text-primary-700 transition-colors">
            Manage
          </a>
        </div>

        <div className="space-y-3">
          {botsLoading ? (
            <>
              <ListItemSkeleton />
              <ListItemSkeleton />
            </>
          ) : copyBots.filter(b => b.isActive).length === 0 ? (
            <p className="text-center py-8 text-content-tertiary">No active copy bots</p>
          ) : (
            copyBots.filter(b => b.isActive).map((bot) => (
              <div key={bot.id} className="flex items-center justify-between p-3 rounded-xl bg-surface-100 hover:bg-surface-200 transition-colors">
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-cyan-50">
                    <Users className="w-4 h-4 text-cyan-600" />
                  </div>
                  <div>
                    <p className="text-sm font-medium text-content-primary">
                      {bot.sourceNickname || `${bot.sourceWalletAddress.slice(0, 4)}...${bot.sourceWalletAddress.slice(-4)}`}
                    </p>
                    <p className="text-xs text-content-tertiary">
                      Max: ${bot.maxTradeSize} • {bot.slippageBps / 100}% slippage
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <span className="badge badge-success">Active</span>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
