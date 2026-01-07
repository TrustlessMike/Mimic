import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { Header } from './Header';

export function AppLayout() {
  return (
    <div className="min-h-screen bg-surface-100">
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
