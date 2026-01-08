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

// ============================================
// Prediction Markets Types
// ============================================

export type BetDirection = 'YES' | 'NO';
export type BetStatus = 'open' | 'won' | 'lost' | 'claimed';

export interface PredictorStats {
  totalBets: number;
  winRate: number;
  totalPnl: number;
  avgBetSize: number;
  lastBetAt?: Timestamp;
}

export interface SmartMoneyWallet {
  id: string;
  address: string;
  nickname?: string;
  notes?: string;
  stats: PredictorStats;
  addedAt: Timestamp;
  addedBy: string;
  isActive: boolean;
  removedAt?: Timestamp;
  removedBy?: string;
}

export interface PredictionBet {
  id: string;
  walletAddress: string;
  walletNickname?: string;
  signature: string;
  timestamp: Timestamp;
  marketAddress: string;
  marketTitle?: string;
  marketCategory?: string;
  direction: BetDirection;
  amount: number;
  shares: number;
  avgPrice: number;
  status: BetStatus;
  pnl?: number;
  canCopy: boolean;
}

// ============================================
// Wallet Tracking Types
// ============================================

export interface WalletStats {
  totalTrades: number;
  winRate: number;
  pnl: number;
  lastTradeAt?: Timestamp;
}

export interface TrackedWallet {
  id: string;
  oduserId: string;
  walletAddress: string;
  nickname?: string;
  createdAt: Timestamp;
  stats: WalletStats;
}

export interface TokenInfo {
  mint: string;
  symbol: string;
  amount: number;
  usdValue?: number;
}

export type TradeType = 'buy' | 'sell';

export interface TrackedTrade {
  id: string;
  walletAddress: string;
  walletNickname?: string;
  signature: string;
  timestamp: Timestamp;
  type: TradeType;
  inputToken: TokenInfo;
  outputToken: TokenInfo;
  isSafeModeTrade: boolean;
  canCopy: boolean;
}

export interface CopyBot {
  id: string;
  userId: string;
  sourceWalletAddress: string;
  sourceNickname?: string;
  isActive: boolean;
  maxTradeSize: number;
  slippageBps: number;
  degenModeEnabled: boolean;
  createdAt: Timestamp;
  stats: {
    totalCopied: number;
    successRate: number;
    totalVolume: number;
  };
}

export interface CopyTradeLog {
  id: string;
  oduserId: string;
  originalTradeId: string;
  inputMint: string;
  outputMint: string;
  inputAmount: string;
  expectedOutput: string;
  platformFeeBps: number;
  degenMode: boolean;
  status: 'pending_signature' | 'submitted' | 'confirmed' | 'failed';
  createdAt: Timestamp;
  signature?: string;
  error?: string;
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

// ============================================
// Kalshi Types (Jupiter uses Kalshi data)
// ============================================

export interface KalshiMarket {
  id: string;
  ticker: string;
  eventTicker: string;
  title: string;
  eventTitle: string;
  category: string;
  yesBid: number;
  yesAsk: number;
  midPrice: number;
  spread: number;
  volume: number;
  volume24h: number;
  liquidity: number;
  jupiterMarketId?: string;
  jupiterEventId?: string;
  jupiterTitle?: string;
  matchType: 'exact_ticker';
  lastSyncedAt: Timestamp;
}

export interface KalshiSignal {
  id: string;
  kalshiTicker: string;
  kalshiEventTicker: string;
  kalshiTitle: string;
  eventTitle: string;
  category: string;
  jupiterMarketId: string;
  jupiterEventId: string;
  jupiterTitle: string;
  direction: 'YES' | 'NO';
  priceChange: number;
  kalshiPrice: number;
  previousPrice: number;
  volume: number;
  signalStrength: number;
  status: 'pending' | 'acted' | 'expired';
  createdAt: Timestamp;
}
