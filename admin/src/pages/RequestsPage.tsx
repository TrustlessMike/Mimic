import { useState } from 'react';
import { format } from 'date-fns';
import { usePaymentRequests } from '../hooks/useFirestore';
import { FileText, Clock, CheckCircle, XCircle, AlertCircle } from 'lucide-react';

const statusTabs = [
  { key: 'all', label: 'All', icon: FileText },
  { key: 'pending', label: 'Pending', icon: Clock },
  { key: 'paid', label: 'Paid', icon: CheckCircle },
  { key: 'expired', label: 'Expired', icon: AlertCircle },
  { key: 'rejected', label: 'Rejected', icon: XCircle },
];

export function RequestsPage() {
  const [statusFilter, setStatusFilter] = useState('all');
  const { requests, loading, error } = usePaymentRequests(statusFilter, 200);

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
      case 'paid':
        return 'badge-success';
      case 'pending':
        return 'badge-warning';
      case 'rejected':
      case 'expired':
        return 'badge-error';
      default:
        return 'badge-neutral';
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-accent-amber/10">
            <FileText className="w-6 h-6 text-accent-amber" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white">Payment Requests</h1>
            <p className="text-sm text-dark-400">{requests.length} requests</p>
          </div>
        </div>
      </div>

      {/* Status Tabs */}
      <div className="tab-list">
        {statusTabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setStatusFilter(tab.key)}
            className={`tab flex items-center gap-2 ${statusFilter === tab.key ? 'tab-active' : ''}`}
          >
            <tab.icon className="w-4 h-4" />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Requests Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>Requester</th>
                <th>Amount</th>
                <th>Status</th>
                <th>Memo</th>
                <th>Created</th>
                <th>Expires</th>
              </tr>
            </thead>
            <tbody>
              {requests.map((request) => (
                <tr key={request.id}>
                  <td>
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-accent-amber to-accent-rose flex items-center justify-center flex-shrink-0">
                        <span className="text-sm font-bold text-white">
                          {(request.requesterName || 'U').charAt(0).toUpperCase()}
                        </span>
                      </div>
                      <div>
                        <p className="text-white font-medium">{request.requesterName || 'Unknown'}</p>
                        <p className="text-xs text-dark-400 font-mono">
                          {request.requesterId?.slice(0, 12)}...
                        </p>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div>
                      <p className="text-white font-semibold">
                        {request.currency ? `${request.currency} ` : ''}
                        {request.amount.toLocaleString()}
                      </p>
                      <p className="text-xs text-dark-400">
                        {request.tokenSymbol || request.currency || 'USDC'}
                        {!request.isFixedAmount && ' (flexible)'}
                      </p>
                    </div>
                  </td>
                  <td>
                    <span className={`badge ${getStatusBadge(request.status)}`}>
                      {request.status}
                    </span>
                  </td>
                  <td>
                    <p className="text-dark-300 max-w-[200px] truncate">
                      {request.memo || '-'}
                    </p>
                  </td>
                  <td className="text-dark-400">
                    {request.createdAt?.toDate
                      ? format(request.createdAt.toDate(), 'MMM d, HH:mm')
                      : '-'}
                  </td>
                  <td className="text-dark-400">
                    {request.expiresAt?.toDate
                      ? format(request.expiresAt.toDate(), 'MMM d')
                      : '-'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {requests.length === 0 && (
          <div className="p-12 text-center">
            <FileText className="w-12 h-12 mx-auto text-dark-500 mb-4" />
            <p className="text-dark-400">No payment requests found</p>
          </div>
        )}
      </div>
    </div>
  );
}
