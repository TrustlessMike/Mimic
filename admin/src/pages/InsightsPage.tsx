import { useState, useEffect } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../services/firebase';
import {
  Sparkles,
  Users,
  ArrowLeftRight,
  FileText,
  RefreshCw,
  TrendingUp,
  DollarSign,
  Loader2,
  Brain,
  Mail,
} from 'lucide-react';
import ReactMarkdown from 'react-markdown';

interface AggregatedData {
  users: {
    total: number;
    newLast7Days: number;
    newLast30Days: number;
    withWallets: number;
  };
  transactions: {
    total: number;
    successRate: number;
    last7Days: number;
    last30Days: number;
    byType: Record<string, number>;
    totalVolumeUsd: number;
  };
  paymentRequests: {
    total: number;
    pending: number;
    paid: number;
    expired: number;
    averageAmount: number;
    totalVolume: number;
  };
  autoSwaps: {
    total: number;
    successRate: number;
    last7Days: number;
    totalVolumeUsd: number;
  };
  coinbase: {
    onramp: {
      total: number;
      completed: number;
      pending: number;
      totalVolume: number;
    };
    offramp: {
      total: number;
      completed: number;
      pending: number;
      totalVolume: number;
    };
  };
}

interface InsightsResponse {
  aggregatedData: AggregatedData;
  insights: string | null;
  error?: string;
  generatedAt: string;
}

export function InsightsPage() {
  const [data, setData] = useState<AggregatedData | null>(null);
  const [insights, setInsights] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [generatingInsights, setGeneratingInsights] = useState(false);
  const [sendingEmail, setSendingEmail] = useState(false);
  const [emailSent, setEmailSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<string | null>(null);

  const fetchData = async (withAI = false) => {
    try {
      if (withAI) {
        setGeneratingInsights(true);
      } else {
        setLoading(true);
      }
      setError(null);

      const functionName = withAI ? 'generateInsights' : 'getAggregatedData';
      const callable = httpsCallable<unknown, InsightsResponse>(functions, functionName);
      const result = await callable({});

      setData(result.data.aggregatedData);
      if (result.data.insights) {
        setInsights(result.data.insights);
      }
      setLastUpdated(result.data.generatedAt);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch data');
    } finally {
      setLoading(false);
      setGeneratingInsights(false);
    }
  };

  useEffect(() => {
    fetchData(false);
  }, []);

  const sendTestEmail = async () => {
    try {
      setSendingEmail(true);
      setEmailSent(false);
      const callable = httpsCallable<unknown, { success: boolean; error?: string }>(
        functions,
        'sendInsightsEmailNow'
      );
      const result = await callable({});
      if (result.data.success) {
        setEmailSent(true);
        setTimeout(() => setEmailSent(false), 5000);
      } else {
        setError(result.data.error || 'Failed to send email');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send email');
    } finally {
      setSendingEmail(false);
    }
  };

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(value);
  };

  const formatPercent = (value: number) => {
    return `${value.toFixed(1)}%`;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-2 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  if (error && !data) {
    return (
      <div className="glass-card p-4 border-accent-rose/30 bg-accent-rose/10">
        <p className="text-accent-rose">{error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-gradient-to-br from-brand-500/20 to-accent-cyan/20">
            <Sparkles className="w-6 h-6 text-brand-400" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white">Insights</h1>
            <p className="text-sm text-dark-400">
              {lastUpdated
                ? `Last updated: ${new Date(lastUpdated).toLocaleString()}`
                : 'Data aggregation & AI analysis'}
            </p>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => fetchData(false)}
            disabled={loading}
            className="btn-secondary gap-2"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
          <button
            onClick={() => fetchData(true)}
            disabled={generatingInsights}
            className="btn-primary gap-2"
          >
            {generatingInsights ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <Brain className="w-4 h-4" />
            )}
            {generatingInsights ? 'Generating...' : 'Generate AI Insights'}
          </button>
          <button
            onClick={sendTestEmail}
            disabled={sendingEmail}
            className="btn-secondary gap-2"
          >
            {sendingEmail ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <Mail className="w-4 h-4" />
            )}
            {sendingEmail ? 'Sending...' : emailSent ? 'Email Sent!' : 'Send Test Email'}
          </button>
        </div>
      </div>

      {/* Email Success Banner */}
      {emailSent && (
        <div className="glass-card p-4 border-accent-emerald/30 bg-accent-emerald/10 flex items-center gap-3">
          <Mail className="w-5 h-5 text-accent-emerald" />
          <p className="text-accent-emerald">Insights email sent to malik@stack-labs.net</p>
        </div>
      )}

      {/* Stats Grid */}
      {data && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {/* Users */}
          <div className="stats-card">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-lg bg-brand-500/10">
                <Users className="w-5 h-5 text-brand-400" />
              </div>
              <span className="text-sm font-medium text-dark-300">Users</span>
            </div>
            <p className="text-3xl font-bold text-white mb-2">{data.users.total}</p>
            <div className="space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-dark-400">New (7d)</span>
                <span className="text-accent-emerald">+{data.users.newLast7Days}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-dark-400">New (30d)</span>
                <span className="text-accent-cyan">+{data.users.newLast30Days}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-dark-400">With Wallets</span>
                <span className="text-white">{data.users.withWallets}</span>
              </div>
            </div>
          </div>

          {/* Transactions */}
          <div className="stats-card">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-lg bg-accent-cyan/10">
                <ArrowLeftRight className="w-5 h-5 text-accent-cyan" />
              </div>
              <span className="text-sm font-medium text-dark-300">Transactions</span>
            </div>
            <p className="text-3xl font-bold text-white mb-2">{data.transactions.total}</p>
            <div className="space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-dark-400">Success Rate</span>
                <span className={data.transactions.successRate >= 95 ? 'text-accent-emerald' : 'text-accent-amber'}>
                  {formatPercent(data.transactions.successRate)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-dark-400">Last 7 days</span>
                <span className="text-white">{data.transactions.last7Days}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-dark-400">Volume</span>
                <span className="text-accent-cyan">{formatCurrency(data.transactions.totalVolumeUsd)}</span>
              </div>
            </div>
          </div>

          {/* Payment Requests */}
          <div className="stats-card">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-lg bg-accent-amber/10">
                <FileText className="w-5 h-5 text-accent-amber" />
              </div>
              <span className="text-sm font-medium text-dark-300">Payment Requests</span>
            </div>
            <p className="text-3xl font-bold text-white mb-2">{data.paymentRequests.total}</p>
            <div className="space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-dark-400">Pending</span>
                <span className="text-accent-amber">{data.paymentRequests.pending}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-dark-400">Paid</span>
                <span className="text-accent-emerald">{data.paymentRequests.paid}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-dark-400">Avg Amount</span>
                <span className="text-white">{formatCurrency(data.paymentRequests.averageAmount)}</span>
              </div>
            </div>
          </div>

          {/* Auto Swaps */}
          <div className="stats-card">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-lg bg-accent-emerald/10">
                <RefreshCw className="w-5 h-5 text-accent-emerald" />
              </div>
              <span className="text-sm font-medium text-dark-300">Auto Swaps</span>
            </div>
            <p className="text-3xl font-bold text-white mb-2">{data.autoSwaps.total}</p>
            <div className="space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-dark-400">Success Rate</span>
                <span className={data.autoSwaps.successRate >= 95 ? 'text-accent-emerald' : 'text-accent-amber'}>
                  {formatPercent(data.autoSwaps.successRate)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-dark-400">Last 7 days</span>
                <span className="text-white">{data.autoSwaps.last7Days}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-dark-400">Volume</span>
                <span className="text-accent-cyan">{formatCurrency(data.autoSwaps.totalVolumeUsd)}</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Coinbase Section */}
      {data && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Onramp */}
          <div className="glass-card p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-lg bg-accent-emerald/10">
                <TrendingUp className="w-5 h-5 text-accent-emerald" />
              </div>
              <div>
                <h3 className="text-lg font-semibold text-white">Coinbase Onramp</h3>
                <p className="text-xs text-dark-400">Fiat to Crypto</p>
              </div>
            </div>
            <div className="grid grid-cols-3 gap-4">
              <div className="text-center">
                <p className="text-2xl font-bold text-white">{data.coinbase.onramp.total}</p>
                <p className="text-xs text-dark-400">Total</p>
              </div>
              <div className="text-center">
                <p className="text-2xl font-bold text-accent-emerald">{data.coinbase.onramp.completed}</p>
                <p className="text-xs text-dark-400">Completed</p>
              </div>
              <div className="text-center">
                <p className="text-2xl font-bold text-accent-amber">{data.coinbase.onramp.pending}</p>
                <p className="text-xs text-dark-400">Pending</p>
              </div>
            </div>
            <div className="mt-4 pt-4 border-t border-dark-700/50">
              <div className="flex items-center justify-between">
                <span className="text-dark-400">Total Volume</span>
                <span className="text-lg font-semibold text-accent-emerald">
                  {formatCurrency(data.coinbase.onramp.totalVolume)}
                </span>
              </div>
            </div>
          </div>

          {/* Offramp */}
          <div className="glass-card p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-lg bg-brand-500/10">
                <DollarSign className="w-5 h-5 text-brand-400" />
              </div>
              <div>
                <h3 className="text-lg font-semibold text-white">Coinbase Offramp</h3>
                <p className="text-xs text-dark-400">Crypto to Fiat</p>
              </div>
            </div>
            <div className="grid grid-cols-3 gap-4">
              <div className="text-center">
                <p className="text-2xl font-bold text-white">{data.coinbase.offramp.total}</p>
                <p className="text-xs text-dark-400">Total</p>
              </div>
              <div className="text-center">
                <p className="text-2xl font-bold text-accent-emerald">{data.coinbase.offramp.completed}</p>
                <p className="text-xs text-dark-400">Completed</p>
              </div>
              <div className="text-center">
                <p className="text-2xl font-bold text-accent-amber">{data.coinbase.offramp.pending}</p>
                <p className="text-xs text-dark-400">Pending</p>
              </div>
            </div>
            <div className="mt-4 pt-4 border-t border-dark-700/50">
              <div className="flex items-center justify-between">
                <span className="text-dark-400">Total Volume</span>
                <span className="text-lg font-semibold text-brand-400">
                  {formatCurrency(data.coinbase.offramp.totalVolume)}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Transaction Types Breakdown */}
      {data && Object.keys(data.transactions.byType).length > 0 && (
        <div className="glass-card p-6">
          <h3 className="text-lg font-semibold text-white mb-4">Transaction Types</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {Object.entries(data.transactions.byType).map(([type, count]) => (
              <div key={type} className="bg-dark-800/50 rounded-xl p-4 text-center">
                <p className="text-2xl font-bold text-white">{count}</p>
                <p className="text-sm text-dark-400 capitalize">{type.replace(/_/g, ' ')}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* AI Insights Section */}
      <div className="glass-card p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="p-2 rounded-lg bg-gradient-to-br from-brand-500/20 to-accent-cyan/20">
            <Brain className="w-5 h-5 text-brand-400" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-white">AI Insights</h3>
            <p className="text-xs text-dark-400">Powered by Claude</p>
          </div>
        </div>

        {generatingInsights ? (
          <div className="flex items-center justify-center py-12">
            <div className="text-center">
              <Loader2 className="w-8 h-8 text-brand-400 animate-spin mx-auto mb-3" />
              <p className="text-dark-400">Analyzing your data...</p>
            </div>
          </div>
        ) : insights ? (
          <div className="prose prose-invert prose-sm max-w-none">
            <ReactMarkdown
              components={{
                h1: ({ children }) => <h1 className="text-xl font-bold text-white mt-4 mb-2">{children}</h1>,
                h2: ({ children }) => <h2 className="text-lg font-semibold text-white mt-4 mb-2">{children}</h2>,
                h3: ({ children }) => <h3 className="text-md font-medium text-white mt-3 mb-1">{children}</h3>,
                p: ({ children }) => <p className="text-dark-200 mb-3">{children}</p>,
                strong: ({ children }) => <strong className="text-brand-400 font-semibold">{children}</strong>,
                ul: ({ children }) => <ul className="list-disc list-inside space-y-1 text-dark-200 mb-3">{children}</ul>,
                ol: ({ children }) => <ol className="list-decimal list-inside space-y-1 text-dark-200 mb-3">{children}</ol>,
                li: ({ children }) => <li className="text-dark-200">{children}</li>,
              }}
            >
              {insights}
            </ReactMarkdown>
          </div>
        ) : (
          <div className="text-center py-12">
            <Brain className="w-12 h-12 text-dark-500 mx-auto mb-4" />
            <p className="text-dark-400 mb-4">
              Click "Generate AI Insights" to get an AI-powered analysis of your data
            </p>
            <button
              onClick={() => fetchData(true)}
              disabled={generatingInsights}
              className="btn-primary gap-2"
            >
              <Sparkles className="w-4 h-4" />
              Generate Insights
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
