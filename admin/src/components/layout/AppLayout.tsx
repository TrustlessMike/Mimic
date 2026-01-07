import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { Header } from './Header';

export function AppLayout() {
  return (
    <div className="min-h-screen bg-dark-950">
      {/* Background gradient effects - positioned behind everything */}
      <div
        className="fixed inset-0 overflow-hidden"
        style={{ zIndex: -1, pointerEvents: 'none' }}
      >
        <div className="absolute -top-40 -right-40 w-80 h-80 bg-brand-500/10 rounded-full blur-3xl"></div>
        <div className="absolute top-1/2 -left-40 w-80 h-80 bg-accent-cyan/5 rounded-full blur-3xl"></div>
        <div className="absolute -bottom-40 right-1/3 w-80 h-80 bg-brand-600/10 rounded-full blur-3xl"></div>
      </div>

      <Sidebar />
      <div className="md:pl-72 flex flex-col min-h-screen" style={{ position: 'relative', zIndex: 1 }}>
        <Header />
        <main className="flex-1 p-6 lg:p-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
