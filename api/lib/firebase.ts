import { initializeApp, getApps, cert, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

function initFirebase() {
  if (getApps().length > 0) {
    return getFirestore();
  }

  // Try service account from env first (for Vercel)
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    initializeApp({
      credential: cert(serviceAccount),
      projectId: 'wickett-13423',
    });
  } else {
    // Fall back to Application Default Credentials (local dev)
    initializeApp({
      credential: applicationDefault(),
      projectId: 'wickett-13423',
    });
  }

  return getFirestore();
}

export const db = initFirebase();
