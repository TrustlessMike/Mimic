import { useState, useMemo } from 'react';
import { format } from 'date-fns';
import { useUsers } from '../hooks/useFirestore';
import { ExternalLink, Users, Search, Copy, Check } from 'lucide-react';

export function UsersPage() {
  const { users, loading, error } = useUsers(500);
  const [search, setSearch] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const filteredUsers = useMemo(() => {
    if (!search) return users;
    const lowerSearch = search.toLowerCase();
    return users.filter(user =>
      user.email?.toLowerCase().includes(lowerSearch) ||
      user.username?.toLowerCase().includes(lowerSearch) ||
      user.walletAddress?.toLowerCase().includes(lowerSearch) ||
      user.displayName?.toLowerCase().includes(lowerSearch)
    );
  }, [users, search]);

  const copyToClipboard = async (text: string, id: string) => {
    await navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
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
          <div className="p-2 rounded-xl bg-brand-500/10">
            <Users className="w-6 h-6 text-brand-400" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white">Users</h1>
            <p className="text-sm text-dark-400">{users.length} total users</p>
          </div>
        </div>

        <div className="relative w-full sm:w-80">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-dark-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by email, username, wallet..."
            className="search-input"
          />
        </div>
      </div>

      {/* Users Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filteredUsers.map((user) => (
          <div key={user.id} className="glass-card p-5 hover:border-brand-500/30 transition-all duration-300">
            <div className="flex items-start gap-4">
              {/* Avatar */}
              <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-brand-400 to-accent-cyan flex items-center justify-center flex-shrink-0">
                <span className="text-lg font-bold text-white">
                  {(user.displayName || user.username || user.email || 'U').charAt(0).toUpperCase()}
                </span>
              </div>

              {/* Info */}
              <div className="flex-1 min-w-0">
                <h3 className="text-base font-semibold text-white truncate">
                  {user.displayName || user.username || 'No name'}
                </h3>
                {user.username && user.displayName && (
                  <p className="text-sm text-brand-400">@{user.username}</p>
                )}
                <p className="text-sm text-dark-400 truncate">{user.email || 'No email'}</p>
              </div>
            </div>

            {/* Wallet Address */}
            {user.walletAddress && (
              <div className="mt-4 p-3 rounded-xl bg-dark-800/50">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-medium text-dark-400">Wallet</span>
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => copyToClipboard(user.walletAddress, user.id)}
                      className="p-1 rounded-lg hover:bg-dark-700 transition-colors"
                    >
                      {copiedId === user.id ? (
                        <Check className="w-3.5 h-3.5 text-accent-emerald" />
                      ) : (
                        <Copy className="w-3.5 h-3.5 text-dark-400" />
                      )}
                    </button>
                    <a
                      href={`https://solscan.io/account/${user.walletAddress}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="p-1 rounded-lg hover:bg-dark-700 transition-colors"
                    >
                      <ExternalLink className="w-3.5 h-3.5 text-dark-400 hover:text-brand-400" />
                    </a>
                  </div>
                </div>
                <p className="mt-1 text-sm font-mono text-white truncate">
                  {user.walletAddress}
                </p>
              </div>
            )}

            {/* Dates */}
            <div className="mt-4 flex items-center justify-between text-xs text-dark-400">
              <span>
                Joined: {user.createdAt?.toDate ? format(user.createdAt.toDate(), 'MMM d, yyyy') : '-'}
              </span>
              <span>
                Active: {user.lastSignIn?.toDate ? format(user.lastSignIn.toDate(), 'MMM d') : '-'}
              </span>
            </div>
          </div>
        ))}
      </div>

      {filteredUsers.length === 0 && (
        <div className="glass-card p-12 text-center">
          <Users className="w-12 h-12 mx-auto text-dark-500 mb-4" />
          <p className="text-dark-400">
            {search ? 'No users match your search' : 'No users found'}
          </p>
        </div>
      )}
    </div>
  );
}
