import { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { LogOut, Bell, Search, FileText, AlertTriangle, X } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import { usePaymentRequests, useTransactions } from '../../hooks/useFirestore';
import { format } from 'date-fns';

export function Header() {
  const { signOut } = useAuth();
  const navigate = useNavigate();
  const [showNotifications, setShowNotifications] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const { requests } = usePaymentRequests('pending', 5);
  const { transactions } = useTransactions(20);

  // Get failed transactions
  const failedTx = transactions.filter(tx => tx.status === 'failed').slice(0, 5);

  const notificationCount = requests.length + failedTx.length;

  const handleNotificationClick = (path: string) => {
    setShowNotifications(false);
    navigate(path);
  };

  // Close dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowNotifications(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <header className="sticky top-0 z-40 bg-white/80 backdrop-blur-xl border-b border-surface-200">
      <div className="px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Search */}
          <div className="flex-1 max-w-lg">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-content-muted" />
              <input
                type="text"
                placeholder="Search anything..."
                className="search-input"
              />
            </div>
          </div>

          {/* Right side */}
          <div className="flex items-center gap-3">
            {/* Notifications */}
            <div className="relative" ref={dropdownRef}>
              <button
                onClick={() => setShowNotifications(!showNotifications)}
                className="relative p-2 rounded-xl text-content-tertiary hover:text-content-primary hover:bg-surface-100 transition-colors"
              >
                <Bell className="w-5 h-5" />
                {notificationCount > 0 && (
                  <span className="absolute top-1 right-1 min-w-[18px] h-[18px] px-1 text-[10px] font-bold bg-rose-500 text-white rounded-full flex items-center justify-center">
                    {notificationCount > 9 ? '9+' : notificationCount}
                  </span>
                )}
              </button>

              {/* Dropdown */}
              {showNotifications && (
                <div className="absolute right-0 mt-2 w-80 bg-white border border-surface-300 rounded-xl shadow-elevated overflow-hidden" style={{ zIndex: 9999 }}>
                  <div className="flex items-center justify-between px-4 py-3 border-b border-surface-200">
                    <h3 className="text-sm font-semibold text-content-primary">Notifications</h3>
                    <button
                      onClick={() => setShowNotifications(false)}
                      className="text-content-tertiary hover:text-content-primary"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>

                  <div className="max-h-80 overflow-y-auto">
                    {notificationCount === 0 ? (
                      <div className="p-4 text-center text-content-tertiary text-sm">
                        No notifications
                      </div>
                    ) : (
                      <>
                        {/* Pending Requests */}
                        {requests.map((req) => (
                          <div
                            key={req.id}
                            onClick={() => handleNotificationClick('/requests')}
                            className="px-4 py-3 hover:bg-surface-100 border-b border-surface-200 cursor-pointer"
                          >
                            <div className="flex items-start gap-3">
                              <div className="p-2 rounded-lg bg-amber-50">
                                <FileText className="w-4 h-4 text-amber-600" />
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="text-sm text-content-primary">Pending payment request</p>
                                <p className="text-xs text-content-tertiary truncate">
                                  ${req.amount} • {req.createdAt?.toDate ? format(req.createdAt.toDate(), 'MMM d, HH:mm') : '-'}
                                </p>
                              </div>
                            </div>
                          </div>
                        ))}

                        {/* Failed Transactions */}
                        {failedTx.map((tx) => (
                          <div
                            key={tx.id}
                            onClick={() => handleNotificationClick('/transactions')}
                            className="px-4 py-3 hover:bg-surface-100 border-b border-surface-200 cursor-pointer"
                          >
                            <div className="flex items-start gap-3">
                              <div className="p-2 rounded-lg bg-rose-50">
                                <AlertTriangle className="w-4 h-4 text-rose-600" />
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="text-sm text-content-primary">Failed transaction</p>
                                <p className="text-xs text-content-tertiary truncate">
                                  {tx.id.slice(0, 12)}... • {tx.timestamp?.toDate ? format(tx.timestamp.toDate(), 'MMM d, HH:mm') : '-'}
                                </p>
                              </div>
                            </div>
                          </div>
                        ))}
                      </>
                    )}
                  </div>
                </div>
              )}
            </div>

            {/* Divider */}
            <div className="h-8 w-px bg-surface-300"></div>

            {/* Sign out */}
            <button
              onClick={signOut}
              className="btn-secondary gap-2 text-sm"
            >
              <LogOut className="h-4 w-4" />
              Sign out
            </button>
          </div>
        </div>
      </div>
    </header>
  );
}
