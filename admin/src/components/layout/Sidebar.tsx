import { NavLink } from 'react-router-dom';
import { LayoutDashboard, Zap, TrendingUp, Eye, BarChart3 } from 'lucide-react';

const navigation = [
  { name: 'Dashboard', href: '/', icon: LayoutDashboard },
  { name: 'Predictions', href: '/predictions', icon: TrendingUp },
  { name: 'Wallet Tracking', href: '/wallet-tracking', icon: Eye },
  { name: 'Polymarket', href: '/polymarket', icon: BarChart3 },
];

export function Sidebar() {
  return (
    <aside
      className="hidden md:flex md:w-72 md:flex-col md:fixed md:inset-y-0 bg-white border-r border-surface-300"
      style={{ zIndex: 9999, position: 'fixed', pointerEvents: 'auto' }}
    >
      {/* Logo Section */}
      <div className="flex items-center gap-3 px-6 py-6 border-b border-surface-200">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-primary-500 to-primary-600 flex items-center justify-center shadow-soft">
          <Zap className="w-5 h-5 text-white" />
        </div>
        <div>
          <h1 className="text-lg font-bold text-content-primary">Mimic</h1>
          <p className="text-xs text-content-tertiary">Admin Dashboard</p>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-4 py-6 space-y-1 overflow-y-auto" style={{ pointerEvents: 'auto' }}>
        <p className="px-4 mb-3 text-xs font-semibold text-content-muted uppercase tracking-wider">
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
                  ? 'bg-primary-50 text-primary-700 border-l-2 border-primary-500'
                  : 'text-content-secondary hover:text-content-primary hover:bg-surface-100'
              }`
            }
          >
            <item.icon className="w-5 h-5" />
            {item.name}
          </NavLink>
        ))}
      </nav>

      {/* Bottom section */}
      <div className="p-4 border-t border-surface-200">
        <div className="bg-surface-100 rounded-2xl p-4 border border-surface-200">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary-400 to-primary-600 flex items-center justify-center shadow-soft">
              <span className="text-sm font-bold text-white">M</span>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-content-primary truncate">Malik</p>
              <p className="text-xs text-content-tertiary truncate">Admin</p>
            </div>
          </div>
        </div>
      </div>
    </aside>
  );
}
