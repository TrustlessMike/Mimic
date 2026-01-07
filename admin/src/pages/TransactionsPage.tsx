import { useState } from 'react';
import { format } from 'date-fns';
import { useTransactions } from '../hooks/useFirestore';
import { ExternalLink, ArrowLeftRight, ArrowUpRight, RefreshCw, Copy, Check } from 'lucide-react';
import type { Transaction, SolanaTransaction } from '../types';

function isTransaction(tx: Transaction | SolanaTransaction): tx is Transaction {
  return 'userId' in tx;
}

const typeFilters = [
  { key: 'all', label: 'All' },
  { key: 'sol_transfer', label: 'SOL Transfers' },
  { key: 'spl_transfer', label: 'Token Transfers' },
  { key: 'swap', label: 'Swaps' },
];

export function TransactionsPage() {
  const { transactions, loading, error } = useTransactions(200);
  const [typeFilter, setTypeFilter] = useState('all');
  const [copiedSig, setCopiedSig] = useState<string | null>(null);

  const filteredTransactions = typeFilter === 'all'
    ? transactions
    : transactions.filter(tx => {
        const type = isTransaction(tx) ? tx.type : tx.transaction_type;
        return type === typeFilter;
      });

  const copySignature = async (sig: string) => {
    await navigator.clipboard.writeText(sig);
    setCopiedSig(sig);
    setTimeout(() => setCopiedSig(null), 2000);
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
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-accent-emerald/10">
            <ArrowLeftRight className="w-6 h-6 text-accent-emerald" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white">Transactions</h1>
            <p className="text-sm text-dark-400">{filteredTransactions.length} transactions</p>
          </div>
        </div>

        {/* Type Filter Tabs */}
        <div className="tab-list">
          {typeFilters.map((filter) => (
            <button
              key={filter.key}
              onClick={() => setTypeFilter(filter.key)}
              className={`tab ${typeFilter === filter.key ? 'tab-active' : ''}`}
            >
              {filter.label}
            </button>
          ))}
        </div>
      </div>

      {/* Transactions Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>Type</th>
                <th>Amount</th>
                <th>Status</th>
                <th>Signature</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {filteredTransactions.map((tx) => {
                const type = isTransaction(tx) ? tx.type : tx.transaction_type;
                const amount = isTransaction(tx) ? tx.amount : (tx.amount_usd ?? tx.amount);
                const signature = isTransaction(tx) ? tx.signature : tx.transaction_signature;
                const recipient = !isTransaction(tx) ? tx.recipient_display : null;

                const getTypeIcon = () => {
                  if (type === 'swap') return <RefreshCw className="w-4 h-4" />;
                  if (type?.includes('transfer')) return <ArrowUpRight className="w-4 h-4" />;
                  return <ArrowLeftRight className="w-4 h-4" />;
                };

                const getTypeColor = () => {
                  if (type === 'swap') return 'bg-accent-cyan/10 text-accent-cyan';
                  if (type === 'sol_transfer') return 'bg-brand-500/10 text-brand-400';
                  if (type === 'spl_transfer') return 'bg-accent-amber/10 text-accent-amber';
                  return 'bg-dark-600/50 text-dark-300';
                };

                return (
                  <tr key={tx.id}>
                    <td>
                      <div className="flex items-center gap-3">
                        <div className={`p-2 rounded-lg ${getTypeColor()}`}>
                          {getTypeIcon()}
                        </div>
                        <div>
                          <p className="text-white font-medium capitalize">
                            {type?.replace('_', ' ') || 'Transaction'}
                          </p>
                          {recipient && (
                            <p className="text-xs text-dark-400">to {recipient}</p>
                          )}
                        </div>
                      </div>
                    </td>
                    <td>
                      <span className="text-white font-medium">
                        {amount !== undefined ? (
                          isTransaction(tx) ? amount.toLocaleString() : `$${Number(amount).toFixed(2)}`
                        ) : '-'}
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${
                        tx.status === 'success' ? 'badge-success' :
                        tx.status === 'failed' ? 'badge-error' : 'badge-warning'
                      }`}>
                        {tx.status}
                      </span>
                    </td>
                    <td>
                      {signature ? (
                        <div className="flex items-center gap-2">
                          <a
                            href={`https://solscan.io/tx/${signature}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-brand-400 hover:text-brand-300 font-mono text-sm flex items-center gap-1"
                          >
                            {signature.slice(0, 8)}...{signature.slice(-4)}
                            <ExternalLink className="w-3 h-3" />
                          </a>
                          <button
                            onClick={() => copySignature(signature)}
                            className="p-1 rounded hover:bg-dark-700 transition-colors"
                          >
                            {copiedSig === signature ? (
                              <Check className="w-3.5 h-3.5 text-accent-emerald" />
                            ) : (
                              <Copy className="w-3.5 h-3.5 text-dark-400" />
                            )}
                          </button>
                        </div>
                      ) : (
                        <span className="text-dark-500">-</span>
                      )}
                    </td>
                    <td className="text-dark-400">
                      {tx.timestamp?.toDate
                        ? format(tx.timestamp.toDate(), 'MMM d, HH:mm')
                        : '-'}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {filteredTransactions.length === 0 && (
          <div className="p-12 text-center">
            <ArrowLeftRight className="w-12 h-12 mx-auto text-dark-500 mb-4" />
            <p className="text-dark-400">No transactions found</p>
          </div>
        )}
      </div>
    </div>
  );
}
