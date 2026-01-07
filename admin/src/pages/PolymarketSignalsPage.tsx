import { memo } from 'react';
import { format } from 'date-fns';
import {
  usePolymarketMarkets,
  usePolymarketStats,
} from '../hooks/usePolymarket';
import { StatCardSkeleton, TableRowSkeleton } from '../components/common/Skeleton';
import {
  BarChart3,
  Link2,
  Target,
  TrendingUp,
  ExternalLink,
  RefreshCw,
  Percent,
} from 'lucide-react';

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

export function PolymarketSignalsPage() {
  const { stats, loading: statsLoading, refetch: refetchStats } = usePolymarketStats();
  const { markets, loading: marketsLoading, refetch: refetchMarkets } = usePolymarketMarkets(50);

  const isLoading = statsLoading || marketsLoading;

  const handleRefresh = () => {
    refetchStats();
    refetchMarkets();
  };

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-violet-50">
            <BarChart3 className="w-6 h-6 text-violet-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-content-primary">Polymarket Signals</h1>
            <p className="text-sm text-content-tertiary">Cross-platform market matching with Jupiter</p>
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
              title="Matched Markets"
              value={stats?.totalMatchedMarkets ?? 0}
              icon={Link2}
              gradient="text-violet-600"
              iconBg="bg-violet-50"
            />
            <StatCard
              title="Cross-Platform Signals"
              value={stats?.totalSignals ?? 0}
              icon={TrendingUp}
              gradient="text-emerald-600"
              iconBg="bg-emerald-50"
            />
            <StatCard
              title="Arbitrage Opportunities"
              value={stats?.activeArbitrageOpportunities ?? 0}
              icon={Target}
              gradient="text-amber-600"
              iconBg="bg-amber-50"
            />
            <StatCard
              title="Avg Match Confidence"
              value={stats?.avgMatchConfidence ? `${stats.avgMatchConfidence}%` : '-'}
              icon={Percent}
              gradient="text-cyan-600"
              iconBg="bg-cyan-50"
            />
          </>
        )}
      </div>

      {/* Matched Markets Table */}
      <div className="glass-card p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-violet-50">
              <Link2 className="w-5 h-5 text-violet-600" />
            </div>
            <h2 className="text-lg font-semibold text-content-primary">Matched Polymarket Markets</h2>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>Polymarket Question</th>
                <th>Event</th>
                <th>Jupiter Match</th>
                <th>Confidence</th>
                <th>Poly YES</th>
                <th>Volume</th>
                <th>Last Synced</th>
                <th>Links</th>
              </tr>
            </thead>
            <tbody>
              {marketsLoading ? (
                <>
                  <TableRowSkeleton cols={8} />
                  <TableRowSkeleton cols={8} />
                  <TableRowSkeleton cols={8} />
                  <TableRowSkeleton cols={8} />
                  <TableRowSkeleton cols={8} />
                </>
              ) : markets.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-8 text-content-tertiary">
                    No Polymarket markets matched yet. Run the sync script to discover matches.
                  </td>
                </tr>
              ) : (
                markets.map((market) => (
                  <tr key={market.id}>
                    <td className="text-content-primary max-w-[250px]">
                      <div className="truncate" title={market.question}>
                        {market.question}
                      </div>
                    </td>
                    <td className="text-content-secondary max-w-[150px]">
                      <div className="truncate" title={market.eventTitle}>
                        {market.eventTitle}
                      </div>
                    </td>
                    <td className="text-content-primary max-w-[200px]">
                      {market.jupiterMarketTitle ? (
                        <div className="truncate" title={market.jupiterMarketTitle}>
                          {market.jupiterMarketTitle}
                        </div>
                      ) : (
                        <span className="text-content-muted">No match</span>
                      )}
                    </td>
                    <td>
                      {market.matchConfidence ? (
                        <span className={`badge ${
                          market.matchConfidence >= 70 ? 'badge-success' :
                          market.matchConfidence >= 50 ? 'badge-warning' : 'badge-neutral'
                        }`}>
                          {market.matchConfidence}%
                        </span>
                      ) : (
                        <span className="text-content-muted">-</span>
                      )}
                    </td>
                    <td>
                      <span className={`font-medium ${
                        market.yesPrice >= 0.7 ? 'text-emerald-600' :
                        market.yesPrice <= 0.3 ? 'text-rose-600' : 'text-content-primary'
                      }`}>
                        {(market.yesPrice * 100).toFixed(1)}%
                      </span>
                    </td>
                    <td className="text-content-secondary">
                      ${market.volume >= 1000000
                        ? `${(market.volume / 1000000).toFixed(1)}M`
                        : market.volume >= 1000
                          ? `${(market.volume / 1000).toFixed(0)}k`
                          : market.volume.toFixed(0)
                      }
                    </td>
                    <td className="text-content-tertiary">
                      {market.lastSyncedAt?.toDate
                        ? format(market.lastSyncedAt.toDate(), 'MMM d, HH:mm')
                        : '-'
                      }
                    </td>
                    <td>
                      <div className="flex items-center gap-2">
                        <a
                          href={`https://polymarket.com/event/${market.conditionId}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="p-1 rounded-lg hover:bg-violet-50 transition-colors inline-flex"
                          title="View on Polymarket"
                        >
                          <ExternalLink className="w-4 h-4 text-violet-600" />
                        </a>
                        {market.jupiterMarketId && (
                          <a
                            href={`https://jup.ag/predictions/${market.jupiterMarketId}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="p-1 rounded-lg hover:bg-emerald-50 transition-colors inline-flex"
                            title="View on Jupiter"
                          >
                            <ExternalLink className="w-4 h-4 text-emerald-600" />
                          </a>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Info Card */}
      <div className="glass-card p-6 border-l-4 border-violet-500">
        <h3 className="text-lg font-semibold text-content-primary mb-2">How Cross-Platform Matching Works</h3>
        <div className="text-sm text-content-secondary space-y-2">
          <p>
            Markets are matched between Polymarket and Jupiter using text similarity analysis.
            A higher confidence score indicates a stronger match between the market questions.
          </p>
          <p>
            To sync markets, run: <code className="bg-surface-100 px-2 py-1 rounded text-violet-600">node scripts/sync-polymarket.js</code>
          </p>
        </div>
      </div>
    </div>
  );
}
