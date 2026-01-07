import { format } from 'date-fns';
import { useAutoSwapLogs } from '../hooks/useFirestore';
import { ExternalLink, RefreshCw, ArrowRight } from 'lucide-react';

export function AutoSwapLogsPage() {
  const { logs, loading, error } = useAutoSwapLogs(200);

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

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'success':
        return 'badge-success';
      case 'failed':
        return 'badge-error';
      case 'partial':
        return 'badge-warning';
      default:
        return 'badge-neutral';
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="p-2 rounded-xl bg-accent-cyan/10">
          <RefreshCw className="w-6 h-6 text-accent-cyan" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-white">Auto-Swap Logs</h1>
          <p className="text-sm text-dark-400">{logs.length} swap operations</p>
        </div>
      </div>

      {/* Logs Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>Swap</th>
                <th>Status</th>
                <th>Signature</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((log) => (
                <tr key={log.id}>
                  <td>
                    <div className="flex items-center gap-3">
                      {/* Input */}
                      <div className="text-right min-w-[100px]">
                        {log.input ? (
                          <>
                            <p className="text-white font-medium">
                              {log.input.amount?.toFixed(4)}
                            </p>
                            <p className="text-xs text-dark-400">{log.input.symbol}</p>
                          </>
                        ) : (
                          <span className="text-dark-500">-</span>
                        )}
                      </div>

                      {/* Arrow */}
                      <div className="p-2 rounded-lg bg-accent-cyan/10">
                        <ArrowRight className="w-4 h-4 text-accent-cyan" />
                      </div>

                      {/* Outputs */}
                      <div className="min-w-[120px]">
                        {log.outputs && log.outputs.length > 0 ? (
                          <div className="space-y-1">
                            {log.outputs.map((output, idx) => (
                              <div key={idx}>
                                <span className="text-white font-medium">
                                  {output.amount?.toFixed(4)}
                                </span>
                                <span className="text-dark-400 ml-1">{output.symbol}</span>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <span className="text-dark-500">-</span>
                        )}
                      </div>

                      {/* Value */}
                      {log.input?.valueUsd && (
                        <div className="ml-4 px-3 py-1 rounded-lg bg-dark-800/50">
                          <span className="text-sm text-dark-300">
                            ${log.input.valueUsd.toFixed(2)}
                          </span>
                        </div>
                      )}
                    </div>
                  </td>
                  <td>
                    <span className={`badge ${getStatusBadge(log.status)}`}>
                      {log.status}
                    </span>
                    {log.error && (
                      <p className="text-xs text-accent-rose mt-1 max-w-[200px] truncate" title={log.error}>
                        {log.error}
                      </p>
                    )}
                  </td>
                  <td>
                    {log.transactionSignature ? (
                      <a
                        href={`https://solscan.io/tx/${log.transactionSignature}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-brand-400 hover:text-brand-300 font-mono text-sm flex items-center gap-1"
                      >
                        {log.transactionSignature.slice(0, 8)}...{log.transactionSignature.slice(-4)}
                        <ExternalLink className="w-3 h-3" />
                      </a>
                    ) : (
                      <span className="text-dark-500">-</span>
                    )}
                  </td>
                  <td className="text-dark-400">
                    {log.timestamp?.toDate
                      ? format(log.timestamp.toDate(), 'MMM d, HH:mm')
                      : '-'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {logs.length === 0 && (
          <div className="p-12 text-center">
            <RefreshCw className="w-12 h-12 mx-auto text-dark-500 mb-4" />
            <p className="text-dark-400">No auto-swap logs found</p>
          </div>
        )}
      </div>
    </div>
  );
}
