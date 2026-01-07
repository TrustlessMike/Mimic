import { initializeApp } from 'firebase/app';
import {
  getAuth,
  signInWithPopup,
  GoogleAuthProvider,
  signOut,
  onAuthStateChanged,
  User
} from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getFunctions } from 'firebase/functions';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const functions = getFunctions(app);

const ALLOWED_EMAIL = 'malik@stack-labs.net';

export async function signInWithGoogle(): Promise<User | null> {
  const provider = new GoogleAuthProvider();
  provider.setCustomParameters({
    login_hint: ALLOWED_EMAIL,
  });

  try {
    const result = await signInWithPopup(auth, provider);

    if (result.user.email !== ALLOWED_EMAIL) {
      await signOut(auth);
      throw new Error('Unauthorized: Only malik@stack-labs.net can access this admin panel.');
    }

    return result.user;
  } catch (error) {
    console.error('Sign in error:', error);
    throw error;
  }
}

export async function logOut(): Promise<void> {
  return signOut(auth);
}

export function subscribeToAuthState(callback: (user: User | null) => void) {
  return onAuthStateChanged(auth, (user) => {
    if (user && user.email !== ALLOWED_EMAIL) {
      signOut(auth);
      callback(null);
    } else {
      callback(user);
    }
  });
}
