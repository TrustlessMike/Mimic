import { Timestamp } from 'firebase/firestore';

export interface User {
  id: string;
  privyUserId: string;
  email: string;
  displayName: string;
  username: string;
  walletAddress: string;
  privyWalletId: string;
  notificationsEnabled: boolean;
  theme: string;
  localCurrency: string;
  preferredPaymentToken: string;
  authProvider: 'privy';
  lastSignIn: Timestamp;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface Transaction {
  id: string;
  userId: string;
  amount: number;
  type: string;
  timestamp: Timestamp;
  signature?: string;
  status: 'pending' | 'success' | 'failed';
  error?: string;
  metadata?: Record<string, unknown>;
}

export interface SolanaTransaction {
  id: string;
  user_id: string;
  transaction_type: 'sol_transfer' | 'spl_transfer' | 'swap';
  amount?: number;
  amount_usd?: number;
  recipient_address?: string;
  recipient_display?: string;
  timestamp: Timestamp;
  status: 'success' | 'failed';
  transaction_signature?: string;
}

export type RequestStatus = 'pending' | 'paid' | 'expired' | 'rejected';

export interface PaymentRequest {
  id: string;
  requesterId: string;
  requesterName: string;
  requesterAddress: string;
  amount: number;
  tokenSymbol: string;
  tokenMint?: string;
  isFixedAmount: boolean;
  memo: string;
  createdAt: Timestamp;
  expiresAt: Timestamp;
  status: RequestStatus;
  paymentCount: number;
  lastPaidAt?: Timestamp;
  currency?: string;
  paidBy?: string;
  paidAt?: Timestamp;
  paymentToken?: string;
}

export interface AutoSwapLog {
  id: string;
  userId: string;
  delegationId: string;
  timestamp: Timestamp;
  input: {
    token: string;
    symbol: string;
    amount: number;
    valueUsd: number;
  };
  outputs: {
    token: string;
    symbol: string;
    amount: number;
    valueUsd: number;
    signature?: string;
  }[];
  status: 'success' | 'failed' | 'partial';
  error?: string;
  totalValueSwapped?: number;
  transactionSignature?: string;
}

export interface DashboardStats {
  totalUsers: number;
  transactionsLast24h: number;
  pendingRequests: number;
  autoSwapsLast24h: number;
}

export type OnrampStatus = 'created' | 'pending' | 'completed' | 'failed' | 'expired';
export type OfframpStatus = 'created' | 'awaiting_crypto' | 'processing' | 'completed' | 'failed' | 'expired';

export interface CoinbaseOnrampSession {
  id: string;
  userId: string;
  coinbaseSessionId: string;
  walletAddress: string;
  assetSymbol: string;
  network: string;
  fiatAmount?: number;
  fiatCurrency: string;
  country: string;
  status: OnrampStatus;
  checkoutUrl: string;
  transactionHash?: string;
  cryptoAmount?: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  completedAt?: Timestamp;
  failureReason?: string;
}

export interface CoinbaseOfframpSession {
  id: string;
  userId: string;
  coinbaseSessionId: string;
  walletAddress: string;
  depositAddress: string;
  assetSymbol: string;
  network: string;
  fiatAmount?: number;
  fiatCurrency: string;
  country: string;
  cryptoAmount?: number;
  status: OfframpStatus;
  checkoutUrl: string;
  transactionHash?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  completedAt?: Timestamp;
  failureReason?: string;
}
