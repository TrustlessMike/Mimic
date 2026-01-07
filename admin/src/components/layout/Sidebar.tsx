import { NavLink } from 'react-router-dom';
import { LayoutDashboard, Users, ArrowLeftRight, FileText, RefreshCw, CreditCard, Zap, Sparkles } from 'lucide-react';

const navigation = [
  { name: 'Dashboard', href: '/', icon: LayoutDashboard },
  { name: 'Insights', href: '/insights', icon: Sparkles },
  { name: 'Users', href: '/users', icon: Users },
  { name: 'Transactions', href: '/transactions', icon: ArrowLeftRight },
  { name: 'Requests', href: '/requests', icon: FileText },
  { name: 'Coinbase', href: '/coinbase', icon: CreditCard },
  { name: 'Auto-Swaps', href: '/auto-swap', icon: RefreshCw },
];

export function Sidebar() {
  return (
    <aside
      className="hidden md:flex md:w-72 md:flex-col md:fixed md:inset-y-0 bg-dark-900 border-r border-dark-700/50"
      style={{ zIndex: 9999, position: 'fixed', pointerEvents: 'auto' }}
    >
      {/* Logo Section */}
      <div className="flex items-center gap-3 px-6 py-6 border-b border-dark-700/50">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-brand-500 to-brand-600 flex items-center justify-center shadow-glow">
          <Zap className="w-5 h-5 text-white" />
        </div>
        <div>
          <h1 className="text-lg font-bold text-white">Wickett</h1>
          <p className="text-xs text-dark-400">Admin Dashboard</p>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-4 py-6 space-y-1 overflow-y-auto" style={{ pointerEvents: 'auto' }}>
        <p className="px-4 mb-3 text-xs font-semibold text-dark-500 uppercase tracking-wider">
          Main Menu
        </p>
        {navigation.map((item) => (
          <NavLink
            key={item.name}
            to={item.href}
            style={{ pointerEvents: 'auto', display: 'flex' }}
            className={({ isActive }) =>
              `items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium cursor-pointer transition-all duration-200 ${
                isActive
                  ? 'bg-gradient-to-r from-brand-600/20 to-brand-500/10 text-white border-l-2 border-brand-500'
                  : 'text-dark-300 hover:text-white hover:bg-dark-700/50'
              }`
            }
          >
            <item.icon className="w-5 h-5" />
            {item.name}
          </NavLink>
        ))}
      </nav>

      {/* Bottom section */}
      <div className="p-4 border-t border-dark-700/50">
        <div className="bg-dark-800/50 backdrop-blur-xl border border-dark-700/50 rounded-2xl p-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-gradient-to-br from-brand-400 to-accent-cyan flex items-center justify-center">
              <span className="text-xs font-bold text-white">M</span>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-white truncate">Malik</p>
              <p className="text-xs text-dark-400 truncate">Admin</p>
            </div>
          </div>
        </div>
      </div>
    </aside>
  );
}
