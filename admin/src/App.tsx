import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './hooks/useAuth';
import { AppLayout } from './components/layout/AppLayout';
import { LoginPage } from './pages/LoginPage';
import { LoadingSpinner } from './components/common/LoadingSpinner';

// Lazy load pages for better initial bundle size
const DashboardPage = lazy(() => import('./pages/DashboardPage').then(m => ({ default: m.DashboardPage })));
const UsersPage = lazy(() => import('./pages/UsersPage').then(m => ({ default: m.UsersPage })));
const TransactionsPage = lazy(() => import('./pages/TransactionsPage').then(m => ({ default: m.TransactionsPage })));
const RequestsPage = lazy(() => import('./pages/RequestsPage').then(m => ({ default: m.RequestsPage })));
const CoinbaseTransfersPage = lazy(() => import('./pages/CoinbaseTransfersPage').then(m => ({ default: m.CoinbaseTransfersPage })));
const AutoSwapLogsPage = lazy(() => import('./pages/AutoSwapLogsPage').then(m => ({ default: m.AutoSwapLogsPage })));
const InsightsPage = lazy(() => import('./pages/InsightsPage').then(m => ({ default: m.InsightsPage })));
const PredictionsPage = lazy(() => import('./pages/PredictionsPage').then(m => ({ default: m.PredictionsPage })));
const WalletTrackingPage = lazy(() => import('./pages/WalletTrackingPage').then(m => ({ default: m.WalletTrackingPage })));

function PageLoader() {
  return (
    <div className="flex items-center justify-center h-64">
      <div className="w-8 h-8 border-2 border-brand-500 border-t-transparent rounded-full animate-spin"></div>
    </div>
  );
}

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100">
        <LoadingSpinner />
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}

function AppRoutes() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100">
        <LoadingSpinner />
      </div>
    );
  }

  return (
    <Routes>
      <Route
        path="/login"
        element={user ? <Navigate to="/" replace /> : <LoginPage />}
      />
      <Route
        element={
          <ProtectedRoute>
            <AppLayout />
          </ProtectedRoute>
        }
      >
        <Route path="/" element={
          <Suspense fallback={<PageLoader />}>
            <DashboardPage />
          </Suspense>
        } />
        <Route path="/users" element={
          <Suspense fallback={<PageLoader />}>
            <UsersPage />
          </Suspense>
        } />
        <Route path="/transactions" element={
          <Suspense fallback={<PageLoader />}>
            <TransactionsPage />
          </Suspense>
        } />
        <Route path="/requests" element={
          <Suspense fallback={<PageLoader />}>
            <RequestsPage />
          </Suspense>
        } />
        <Route path="/coinbase" element={
          <Suspense fallback={<PageLoader />}>
            <CoinbaseTransfersPage />
          </Suspense>
        } />
        <Route path="/auto-swap" element={
          <Suspense fallback={<PageLoader />}>
            <AutoSwapLogsPage />
          </Suspense>
        } />
        <Route path="/insights" element={
          <Suspense fallback={<PageLoader />}>
            <InsightsPage />
          </Suspense>
        } />
        <Route path="/predictions" element={
          <Suspense fallback={<PageLoader />}>
            <PredictionsPage />
          </Suspense>
        } />
        <Route path="/wallet-tracking" element={
          <Suspense fallback={<PageLoader />}>
            <WalletTrackingPage />
          </Suspense>
        } />
      </Route>
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  );
}
