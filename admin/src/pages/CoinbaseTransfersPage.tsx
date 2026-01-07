import { useState } from 'react';
import { format } from 'date-fns';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { useCoinbaseTransfers } from '../hooks/useFirestore';
import { ExternalLink, ArrowDownCircle, ArrowUpCircle, RefreshCw, Download, CheckCircle, XCircle, Edit3, Webhook, CreditCard, X } from 'lucide-react';
import type { CoinbaseOnrampSession, CoinbaseOfframpSession } from '../types';

const typeTabs = [
  { key: 'all', label: 'All', icon: CreditCard },
  { key: 'onramp', label: 'Buy', icon: ArrowDownCircle },
  { key: 'offramp', label: 'Sell', icon: ArrowUpCircle },
];

function isOnramp(transfer: CoinbaseOnrampSession | CoinbaseOfframpSession): transfer is CoinbaseOnrampSession & { _type: 'onramp' } {
  return '_type' in transfer && (transfer as { _type: string })._type === 'onramp';
}

export function CoinbaseTransfersPage() {
  const [typeFilter, setTypeFilter] = useState<'all' | 'onramp' | 'offramp'>('all');
  const { transfers, loading, error } = useCoinbaseTransfers(typeFilter, 200);
  const [syncing, setSyncing] = useState(false);
  const [syncingId, setSyncingId] = useState<string | null>(null);
  const [apiTransactions, setApiTransactions] = useState<unknown[] | null>(null);
  const [apiError, setApiError] = useState<string | null>(null);
  const [updatingId, setUpdatingId] = useState<string | null>(null);
  const [editingSession, setEditingSession] = useState<{
    id: string;
    type: 'onramp' | 'offramp';
    currentStatus: string;
  } | null>(null);
  const [registeringWebhook, setRegisteringWebhook] = useState(false);
  const [webhookResult, setWebhookResult] = useState<Record<string, unknown> | null>(null);

  const functions = getFunctions();

  const fetchFromCoinbaseAPI = async () => {
    setSyncing(true);
    setApiError(null);
    try {
      const adminGetTransactions = httpsCallable(functions, 'adminGetCoinbaseTransactions');
      const result = await adminGetTransactions({ syncFromApi: true });
      const data = result.data as {
        transactions: unknown[];
        apiTransactions?: unknown[];
        source?: string;
        errors?: string[];
      };

      if (data.apiTransactions && data.apiTransactions.length > 0) {
        setApiTransactions(data.apiTransactions);
      } else {
        setApiTransactions(data.transactions);
      }

      if (data.errors && data.errors.length > 0) {
        setApiError(`Some API calls failed: ${data.errors.join(', ')}`);
      } else if (data.source === 'firestore') {
        setApiError('No pending sessions to sync from API');
      }
    } catch (err: unknown) {
      setApiError(err instanceof Error ? err.message : 'Failed to fetch from Coinbase API');
    } finally {
      setSyncing(false);
    }
  };

  const syncSession = async (sessionId: string, sessionType: 'onramp' | 'offramp') => {
    setSyncingId(sessionId);
    try {
      const adminSyncSession = httpsCallable(functions, 'adminSyncCoinbaseSession');
      await adminSyncSession({ sessionId, sessionType });
      window.location.reload();
    } catch (err: unknown) {
      alert(`Sync failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setSyncingId(null);
    }
  };

  const updateSessionStatus = async (
    sessionId: string,
    sessionType: 'onramp' | 'offramp',
    newStatus: string
  ) => {
    setUpdatingId(sessionId);
    try {
      const adminUpdateStatus = httpsCallable(functions, 'adminUpdateSessionStatus');
      await adminUpdateStatus({
        sessionId,
        sessionType,
        status: newStatus,
      });
      setEditingSession(null);
      window.location.reload();
    } catch (err: unknown) {
      alert(`Update failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setUpdatingId(null);
    }
  };

  const markAsCompleted = async (sessionId: string, sessionType: 'onramp' | 'offramp') => {
    if (confirm('Mark this transaction as completed?')) {
      await updateSessionStatus(sessionId, sessionType, 'completed');
    }
  };

  const markAsFailed = async (sessionId: string, sessionType: 'onramp' | 'offramp') => {
    if (confirm('Mark this transaction as failed?')) {
      await updateSessionStatus(sessionId, sessionType, 'failed');
    }
  };

  const registerWebhook = async () => {
    if (!confirm('Register webhook with Coinbase? This should only be done once.')) {
      return;
    }
    setRegisteringWebhook(true);
    setWebhookResult(null);
    try {
      const adminRegisterWebhook = httpsCallable(functions, 'adminRegisterCoinbaseWebhook');
      const result = await adminRegisterWebhook({});
      setWebhookResult(result.data as Record<string, unknown>);
      alert('Webhook registered successfully!');
    } catch (err: unknown) {
      setWebhookResult({ error: err instanceof Error ? err.message : 'Unknown error' });
      alert(`Failed to register webhook: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setRegisteringWebhook(false);
    }
  };

  const listWebhooks = async () => {
    setRegisteringWebhook(true);
    setWebhookResult(null);
    try {
      const adminListWebhooks = httpsCallable(functions, 'adminListCoinbaseWebhooks');
      const result = await adminListWebhooks({});
      setWebhookResult(result.data as Record<string, unknown>);
    } catch (err: unknown) {
      setWebhookResult({ error: err instanceof Error ? err.message : 'Unknown error' });
    } finally {
      setRegisteringWebhook(false);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'completed':
        return 'badge-success';
      case 'pending':
      case 'awaiting_crypto':
      case 'processing':
        return 'badge-warning';
      case 'failed':
      case 'expired':
        return 'badge-error';
      default:
        return 'badge-neutral';
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-2 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="glass-card p-4 border-accent-rose/30 bg-accent-rose/10">
        <p className="text-accent-rose">{error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-brand-500/10">
            <CreditCard className="w-6 h-6 text-brand-400" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white">Coinbase Transfers</h1>
            <p className="text-sm text-dark-400">{transfers.length} transfers</p>
          </div>
        </div>

        <div className="flex flex-wrap gap-2">
          <button
            onClick={listWebhooks}
            disabled={registeringWebhook}
            className="btn-secondary gap-2 text-sm"
          >
            {registeringWebhook ? <RefreshCw className="h-4 w-4 animate-spin" /> : <Webhook className="h-4 w-4" />}
            Webhooks
          </button>
          <button
            onClick={registerWebhook}
            disabled={registeringWebhook}
            className="btn-secondary gap-2 text-sm border-accent-emerald/30 text-accent-emerald hover:bg-accent-emerald/10"
          >
            {registeringWebhook ? <RefreshCw className="h-4 w-4 animate-spin" /> : <Webhook className="h-4 w-4" />}
            Register
          </button>
          <button
            onClick={fetchFromCoinbaseAPI}
            disabled={syncing}
            className="btn-primary gap-2 text-sm"
          >
            {syncing ? <RefreshCw className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}
            Sync from API
          </button>
        </div>
      </div>

      {/* Webhook Result */}
      {webhookResult && (
        <div className="glass-card p-4 border-brand-500/30">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-medium text-brand-400">Webhook Response</h3>
            <button onClick={() => setWebhookResult(null)} className="text-dark-400 hover:text-white">
              <X className="w-4 h-4" />
            </button>
          </div>
          <pre className="text-xs text-dark-300 overflow-auto max-h-40 font-mono">
            {JSON.stringify(webhookResult, null, 2)}
          </pre>
        </div>
      )}

      {/* API Error */}
      {apiError && (
        <div className="glass-card p-4 border-accent-amber/30 bg-accent-amber/5">
          <p className="text-sm text-accent-amber">{apiError}</p>
        </div>
      )}

      {/* API Transactions */}
      {apiTransactions && (
        <div className="glass-card p-4 border-accent-cyan/30">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-medium text-accent-cyan">
              API Response ({apiTransactions.length} transactions)
            </h3>
            <button onClick={() => setApiTransactions(null)} className="text-dark-400 hover:text-white">
              <X className="w-4 h-4" />
            </button>
          </div>
          <pre className="text-xs text-dark-300 overflow-auto max-h-40 font-mono">
            {JSON.stringify(apiTransactions, null, 2)}
          </pre>
        </div>
      )}

      {/* Type Tabs */}
      <div className="tab-list">
        {typeTabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setTypeFilter(tab.key as 'all' | 'onramp' | 'offramp')}
            className={`tab flex items-center gap-2 ${typeFilter === tab.key ? 'tab-active' : ''}`}
          >
            <tab.icon className="w-4 h-4" />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Transfers Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>Type</th>
                <th>Amount</th>
                <th>Status</th>
                <th>Tx Hash</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {transfers.map((transfer) => {
                const transferType = isOnramp(transfer) ? 'onramp' : 'offramp';

                return (
                  <tr key={transfer.id}>
                    <td>
                      <div className="flex items-center gap-3">
                        <div className={`p-2 rounded-lg ${transferType === 'onramp' ? 'bg-accent-emerald/10' : 'bg-accent-cyan/10'}`}>
                          {transferType === 'onramp' ? (
                            <ArrowDownCircle className="w-4 h-4 text-accent-emerald" />
                          ) : (
                            <ArrowUpCircle className="w-4 h-4 text-accent-cyan" />
                          )}
                        </div>
                        <div>
                          <p className="text-white font-medium">{transferType === 'onramp' ? 'Buy' : 'Sell'}</p>
                          <p className="text-xs text-dark-400">{transfer.assetSymbol}</p>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div>
                        {transfer.fiatAmount ? (
                          <p className="text-white font-semibold">
                            ${transfer.fiatAmount.toLocaleString()} {transfer.fiatCurrency}
                          </p>
                        ) : null}
                        {transfer.cryptoAmount ? (
                          <p className="text-xs text-dark-400">
                            {transfer.cryptoAmount.toFixed(4)} {transfer.assetSymbol}
                          </p>
                        ) : null}
                        {!transfer.fiatAmount && !transfer.cryptoAmount && (
                          <span className="text-dark-500">-</span>
                        )}
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${getStatusBadge(transfer.status)}`}>
                        {transfer.status}
                      </span>
                      {transfer.failureReason && (
                        <p className="text-xs text-accent-rose mt-1 max-w-[150px] truncate" title={transfer.failureReason}>
                          {transfer.failureReason}
                        </p>
                      )}
                    </td>
                    <td>
                      {transfer.transactionHash ? (
                        <a
                          href={`https://solscan.io/tx/${transfer.transactionHash}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-brand-400 hover:text-brand-300 font-mono text-sm flex items-center gap-1"
                        >
                          {transfer.transactionHash.slice(0, 8)}...
                          <ExternalLink className="w-3 h-3" />
                        </a>
                      ) : (
                        <span className="text-dark-500">-</span>
                      )}
                    </td>
                    <td className="text-dark-400">
                      {transfer.createdAt?.toDate
                        ? format(transfer.createdAt.toDate(), 'MMM d, HH:mm')
                        : '-'}
                    </td>
                    <td>
                      <div className="flex items-center gap-1">
                        <button
                          onClick={() => syncSession(transfer.id, transferType)}
                          disabled={syncingId === transfer.id || updatingId === transfer.id}
                          className="p-2 rounded-lg hover:bg-dark-700 text-dark-400 hover:text-white transition-colors disabled:opacity-50"
                          title="Sync from API"
                        >
                          {syncingId === transfer.id ? (
                            <RefreshCw className="h-4 w-4 animate-spin" />
                          ) : (
                            <RefreshCw className="h-4 w-4" />
                          )}
                        </button>
                        {transfer.status !== 'completed' && (
                          <>
                            <button
                              onClick={() => markAsCompleted(transfer.id, transferType)}
                              disabled={updatingId === transfer.id}
                              className="p-2 rounded-lg hover:bg-accent-emerald/10 text-dark-400 hover:text-accent-emerald transition-colors disabled:opacity-50"
                              title="Mark completed"
                            >
                              <CheckCircle className="h-4 w-4" />
                            </button>
                            <button
                              onClick={() => markAsFailed(transfer.id, transferType)}
                              disabled={updatingId === transfer.id}
                              className="p-2 rounded-lg hover:bg-accent-rose/10 text-dark-400 hover:text-accent-rose transition-colors disabled:opacity-50"
                              title="Mark failed"
                            >
                              <XCircle className="h-4 w-4" />
                            </button>
                          </>
                        )}
                        <button
                          onClick={() => setEditingSession({
                            id: transfer.id,
                            type: transferType,
                            currentStatus: transfer.status,
                          })}
                          className="p-2 rounded-lg hover:bg-dark-700 text-dark-400 hover:text-white transition-colors"
                          title="Edit status"
                        >
                          <Edit3 className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {transfers.length === 0 && (
          <div className="p-12 text-center">
            <CreditCard className="w-12 h-12 mx-auto text-dark-500 mb-4" />
            <p className="text-dark-400">No Coinbase transfers found</p>
          </div>
        )}
      </div>

      {/* Edit Status Modal */}
      {editingSession && (
        <div className="fixed inset-0 bg-dark-950/80 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="glass-card p-6 max-w-md w-full mx-4">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-semibold text-white">Update Status</h3>
              <button
                onClick={() => setEditingSession(null)}
                className="p-2 rounded-lg hover:bg-dark-700 text-dark-400 hover:text-white transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <p className="text-sm text-dark-400 mb-2">Session ID</p>
            <p className="text-sm font-mono text-white mb-4 bg-dark-800/50 p-2 rounded-lg">
              {editingSession.id.slice(0, 24)}...
            </p>

            <p className="text-sm text-dark-400 mb-2">Current Status</p>
            <span className={`badge ${getStatusBadge(editingSession.currentStatus)} mb-6`}>
              {editingSession.currentStatus}
            </span>

            <p className="text-sm text-dark-400 mb-3">Select New Status</p>
            <div className="flex flex-wrap gap-2">
              {['created', 'pending', 'completed', 'failed', 'expired'].map((status) => (
                <button
                  key={status}
                  onClick={() => updateSessionStatus(editingSession.id, editingSession.type, status)}
                  disabled={updatingId === editingSession.id}
                  className={`px-4 py-2 rounded-xl text-sm font-medium transition-all disabled:opacity-50 ${
                    status === 'completed'
                      ? 'bg-accent-emerald/20 text-accent-emerald hover:bg-accent-emerald/30 border border-accent-emerald/30'
                      : status === 'failed' || status === 'expired'
                      ? 'bg-accent-rose/20 text-accent-rose hover:bg-accent-rose/30 border border-accent-rose/30'
                      : status === 'pending'
                      ? 'bg-accent-amber/20 text-accent-amber hover:bg-accent-amber/30 border border-accent-amber/30'
                      : 'bg-dark-700/50 text-dark-300 hover:bg-dark-600/50 border border-dark-600'
                  }`}
                >
                  {updatingId === editingSession.id ? 'Updating...' : status}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
