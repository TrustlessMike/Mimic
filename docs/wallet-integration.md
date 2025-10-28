# Wallet Integration - Implementation Progress

**Started:** October 27, 2025
**Status:** 🚧 In Progress

---

## Overview

Transforming Wickett from a placeholder wallet app into a fully functional Solana-powered digital wallet with **zero blockchain friction**. Users will never know they're using blockchain technology.

### Core Philosophy
- **NO blockchain jargon** - It's just "send money", not "submit transaction"
- **Instant feedback** - Optimistic UI updates before blockchain confirms
- **Delightful animations** - Every action feels satisfying
- **Gasless experience** - Backend sponsors all fees
- **Banking app UX** - Familiar flows like Venmo/Cash App

---

## Phase 1: Foundation Models ✅ COMPLETE

### 1. SolanaToken Model
**File:** `Sources/Wickett/Core/Solana/Models/SolanaToken.swift`

**Purpose:** Define supported tokens with visual styling

**Key Features:**
- Token metadata (symbol, name, mint address, decimals)
- Color gradients for UI display
- Amount formatting helpers
- Lamports ↔ Decimal conversion

**Supported Tokens:**
```swift
TokenRegistry.SOL   // Native Solana
TokenRegistry.USDC  // USD Coin stablecoin
TokenRegistry.BONK  // Memecoin
```

**Token Addresses (Mainnet):**
- SOL: Native (no mint address)
- USDC: `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v`
- BONK: `DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263`

### 2. TokenBalance Model
**File:** `Sources/Wickett/Core/Solana/Models/TokenBalance.swift`

**Purpose:** Track user's balance for each token with USD conversion

**Key Features:**
- Stores balance in lamports (smallest unit)
- USD price integration
- 24h price change tracking
- Display formatters (e.g., "1.25 SOL", "$245.50")
- Firestore serialization

**Example:**
```swift
let balance = TokenBalance(
    token: TokenRegistry.SOL,
    lamports: 1_250_000_000,  // 1.25 SOL
    usdPrice: 196.40
)

balance.displayAmount  // "1.25 SOL"
balance.displayUSD     // "$245.50"
```

### 3. WalletActivity Model
**File:** `Sources/Wickett/Core/Solana/Models/WalletActivity.swift`

**Purpose:** User-friendly transaction representation (NO blockchain jargon!)

**Activity Types:**
- `sent` - "Sent 0.5 SOL to Mike"
- `received` - "Received 100 USDC"
- `swapped` - "Swapped SOL → USDC"

**Status Types:**
- `pending` - Transaction in progress
- `completed` - Success ✓
- `failed` - Something went wrong

**User-Facing vs Internal:**
```swift
// What user sees:
activity.title  // "Sent SOL to Mike"
activity.subtitle  // "0.5 SOL • 2:30 PM"

// What's hidden (for power users only):
activity.signature  // Transaction hash
activity.explorerUrl  // Solscan link
```

**Key Design Decision:**
- Blockchain details (signature, explorer URL) are stored but hidden by default
- Only shown in expanded detail view for power users
- Counterparty can be nickname ("Mike") instead of wallet address

---

## Phase 2: Service Layer 🚧 IN PROGRESS

### 4. SolanaWalletService (Next)
**File:** `Sources/Wickett/Core/Solana/SolanaWalletService.swift`

**Purpose:** Manage wallet state with optimistic UI updates

**Planned Features:**
- Fetch balances from Helius RPC
- Cache balances locally
- Optimistic updates (update UI immediately, rollback on failure)
- Background refresh every 10s
- Observable state management

**Optimistic Update Flow:**
```
User taps "Send" →
  1. Immediately deduct from UI balance
  2. Show "Sending..." toast
  3. Call Cloud Function in background
  4. If success: Keep update, show confetti
  5. If failure: Rollback UI, show error
```

### 5. TransactionService (Planned)
**File:** `Sources/Wickett/Core/Solana/TransactionService.swift`

**Purpose:** Wrapper around Cloud Functions with user-friendly API

**Planned Methods:**
```swift
// User-friendly method names (NO blockchain jargon)
func sendMoney(amount: Decimal, currency: String, to: String) async throws
func swap(from: String, to: String, amount: Decimal) async throws
func getRecentActivity() async throws -> [WalletActivity]
```

**Internal Mapping:**
- `sendMoney()` → `sponsorSolTransfer` or `sponsorSplTransfer`
- `swap()` → `sponsorJupiterSwap`
- `getRecentActivity()` → Firestore query

### 6. PriceFeedService (Planned)
**File:** `Sources/Wickett/Core/Solana/PriceFeedService.swift`

**Purpose:** Fetch and cache token prices for USD conversion

**Planned Features:**
- CoinGecko API integration
- Update prices every 30s
- Cache with expiration
- Calculate total portfolio value

---

## Phase 3: UI Components (Planned)

### 7. Redesigned WalletView
**Current:** Payment methods placeholder (credit cards, bank accounts)
**New:** Solana wallet with balances and action buttons

**Layout:**
```
┌─────────────────────────────┐
│   Total Balance             │
│   $1,234.56                 │
│   +2.3% today               │
└─────────────────────────────┘

[Send]  [Swap]  [Receive]

Your Currencies
◉ Solana • 1.25 SOL • $245.50
$ USD Coin • 500 USDC • $500.00
🐕 Bonk • 1.2M BONK • $12.45

Recent Activity
↑ Sent 0.5 SOL • 2 hours ago
```

### 8. SendMoneySheet (Planned)
**Flow:** Amount → Recipient → Confirm → Success

**Key Features:**
- Lead with USD, show token amount as secondary
- Nickname system for saved addresses
- Slide-to-send confirmation
- Confetti animation on success

### 9. SwapSheet (Planned)
**Flow:** Select tokens → Enter amount → Get quote → Confirm → Success

**Key Features:**
- Live price quotes from Jupiter
- Show 0.8% fee transparently
- Reverse button with animation
- Particle effects on success

### 10. ReceiveSheet (Planned)
**Features:**
- Large QR code
- Copy address button
- Share functionality
- Works with all supported tokens

---

## Phase 4: Polish (Planned)

### 11. Animations & Haptics
- Confetti on successful transactions
- Spring animations for buttons
- Shimmer/pulse for loading states
- Count-up animation for balance changes
- Haptic feedback on all interactions

### 12. Error Handling
**Blockchain Errors → User-Friendly Messages:**
- "Insufficient funds" → "You don't have enough SOL"
- "Transaction failed" → "Something went wrong. Try again?"
- "Network error" → "Connection issue. Check your internet."

**Never show:**
- ❌ "Transaction simulation failed"
- ❌ "RPC error 429"
- ❌ "Signature verification failed"

---

## Technical Stack

### Backend (Already Deployed ✅)
- Firebase Cloud Functions Gen 2
- 4 Functions: SOL transfer, SPL transfer, Jupiter swap, Custom instruction
- Transaction sponsorship (gasless for users)
- Helius RPC for Solana mainnet
- Fee collection: 0.8% on swaps

### iOS Frontend
- SwiftUI for all UI
- Combine for reactive state
- Firebase iOS SDK for Cloud Functions
- Privy iOS SDK for authentication
- No direct Solana SDK (all blockchain calls via backend)

### Data Flow
```
iOS App
  ↓ (Firebase Callable)
Cloud Function
  ↓ (Helius RPC)
Solana Blockchain
  ↓ (Confirmation)
Firestore (transaction log)
  ↓ (Real-time listener)
iOS App (activity feed update)
```

---

## Progress Checklist

### Phase 1: Models ✅
- [x] SolanaToken model
- [x] TokenBalance model
- [x] WalletActivity model
- [x] Build verification

### Phase 2: Services 🚧
- [ ] SolanaWalletService
- [ ] TransactionService
- [ ] PriceFeedService
- [ ] Integration tests

### Phase 3: UI Components
- [ ] Redesign WalletView
- [ ] SendMoneySheet
- [ ] SwapSheet
- [ ] ReceiveSheet
- [ ] ActivityView updates

### Phase 4: Polish
- [ ] Success animations
- [ ] Loading states
- [ ] Error handling
- [ ] Haptic feedback
- [ ] Accessibility

### Phase 5: Testing
- [ ] Unit tests for services
- [ ] UI tests for flows
- [ ] End-to-end testing
- [ ] Performance testing

---

## Key Design Decisions

### 1. Optimistic UI Updates
**Why:** Users expect instant feedback, not 3-5s wait for blockchain confirmation

**How:** Update UI immediately, call backend async, rollback on failure

**Trade-off:** Slight complexity in state management, but much better UX

### 2. Hide Blockchain Complexity
**Why:** 99% of users don't care about "transactions" or "signatures"

**How:** Use banking terminology (send money, not submit transaction)

**Progressive Disclosure:** Advanced users can expand details to see blockchain info

### 3. Gasless Transactions
**Why:** Paying "gas fees" is confusing and adds friction

**How:** Backend sponsors all fees via fee payer wallet

**Monetization:** 0.8% fee on swaps (transparent to user)

### 4. USD-First Display
**Why:** Users think in dollars, not token amounts

**How:** Lead with USD value, show token amount as secondary

**Example:** "$245.50" (1.25 SOL) instead of "1.25 SOL ($245.50)"

---

## Next Steps

1. **Implement SolanaWalletService** - Core service for balance management
2. **Implement PriceFeedService** - USD conversion for all tokens
3. **Implement TransactionService** - Cloud Function wrappers
4. **Redesign WalletView** - Replace placeholder with real wallet UI
5. **Build transaction flows** - Send, Swap, Receive sheets
6. **Add animations** - Confetti, haptics, success states
7. **Test end-to-end** - Complete flows from iOS to blockchain

---

## Resources

### Documentation
- [Helius RPC Docs](https://docs.helius.dev/)
- [Jupiter API Docs](https://station.jup.ag/docs/apis/swap-api)
- [Solana Web3.js](https://solana-labs.github.io/solana-web3.js/)
- [Firebase Functions](https://firebase.google.com/docs/functions)

### Related Docs
- `BACKEND-TESTING-COMPLETE.md` - All 4 Cloud Functions tested ✅
- `FINAL-FEE-STRUCTURE.md` - 0.8% swap fee breakdown
- `JUPITER-REFERRAL-SETUP.md` - Referral wallet configuration

---

**Last Updated:** October 27, 2025
**Next Task:** Implement SolanaWalletService with optimistic updates
