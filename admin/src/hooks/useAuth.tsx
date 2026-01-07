import { useState, useEffect, createContext, useContext, ReactNode } from 'react';
import { User } from 'firebase/auth';
import { subscribeToAuthState, signInWithGoogle, logOut } from '../services/firebase';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  error: string | null;
  signIn: () => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const unsubscribe = subscribeToAuthState((user) => {
      setUser(user);
      setLoading(false);
    });
    return unsubscribe;
  }, []);

  const signIn = async () => {
    setError(null);
    try {
      await signInWithGoogle();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign in failed');
    }
  };

  const handleSignOut = async () => {
    await logOut();
  };

  return (
    <AuthContext.Provider value={{ user, loading, error, signIn, signOut: handleSignOut }}>
      {children}
    </AuthContext.Provider>
  );
}
