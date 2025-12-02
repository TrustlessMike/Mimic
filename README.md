# Wickett - Venmo for Crypto

Global payment app using Solana blockchain for instant, low-cost money transfers.

## Project Status

✅ **Core Features Complete** - Wallet, Send, Authentication, Backend (all tested on mainnet)
🚧 **Pre-Launch** - Ready for TestFlight beta testing
📋 **Next Up** - User testing, transaction history

## Tech Stack

- **Backend**: Firebase Cloud Functions (TypeScript)
- **Blockchain**: Solana (SOL, USDC, SPL tokens)
- **Fiat Rails**: Coinbase Onramp/Offramp
- **Frontend**: SwiftUI iOS app (iOS 16+)
- **Auth**: Privy embedded wallets

## Cloud Functions (Production)

| Function | Purpose | Status |
|----------|---------|--------|
| `createFirebaseCustomToken` | Privy → Firebase auth bridge | ✅ Deployed |
| `sponsorSolTransferV2` | Build partial SOL transfer with fee payer signature | ✅ Tested mainnet |
| `sponsorSplTransferV2` | Build partial SPL transfer with ATA creation | ✅ Tested mainnet |
| `broadcastSignedTransaction` | Verify and broadcast user-signed transactions | ✅ Tested mainnet |
| `getRecentRecipients` | Fetch user's recent transaction recipients | ✅ Deployed |
| `getFeePayerAddress` | Get sponsorship wallet address | ✅ Deployed |
| `monitorFeePayerBalance` | Hourly wallet balance monitoring | ✅ Deployed |
| `checkFeePayerBalance` | Manual balance check (callable) | ✅ Deployed |

**Mainnet Testing:**
- 8 confirmed transactions
- 100% success rate
- Total cost: ~0.011 SOL (~$2.20)

## Features

### ✅ Implemented (Production Ready)
- [x] **Authentication** - Privy OAuth (Apple/Google Sign-In) with embedded wallets
- [x] **Wallet Display** - Real-time balances for SOL and 8 SPL tokens with USD pricing
- [x] **Send Feature** - Complete SOL/SPL token transfers with user signing
- [x] **Gas Sponsorship** - Zero fees for users, backend pays all transaction costs
- [x] **V2 Transaction Architecture** - User signing with backend fee payer sponsorship
- [x] **Onboarding Flow** - Welcome, terms acceptance, display name setup, preferences
- [x] **Theme System** - Light/Dark mode with brand colors and gradients
- [x] **Balance Monitoring** - Hourly automated fee payer wallet checks

### 🚧 In Progress
- [ ] Transaction history display
- [ ] Receive feature (QR codes)
- [ ] User handles (@username system)
- [ ] Gold verification badges (early adopters)

### 📋 Planned
- [ ] Jupiter swap UI
- [ ] SNS .sol domain support
- [ ] Address book / contacts
- [ ] Portfolio charts and analytics

## Documentation

Documentation is organized into the following categories:

### Setup & Configuration
- [Firebase Remote Config Setup](docs/setup/firebase-remote-config.md) - Configure Helius RPC and feature flags
- [Dev Contact Setup](docs/setup/dev-contact-setup.md) - Add test contacts for development
- [Auth Session Management](docs/AUTH-SESSION-MANAGEMENT.md) - Firebase and GCloud authentication persistence

### Feature Implementation
- [Wallet Integration](docs/features/wallet-integration.md) - Real-time balance display with Helius RPC
- [Send Feature](docs/features/send-feature.md) - Complete implementation of SOL/SPL transfers
- [Privy Signing Integration](docs/features/privy-signing.md) - End-to-end transaction signing with Privy
- [Launch Screen](docs/features/launch-screen.md) - App launch screen implementation
- [Auto-Convert System](docs/features/auto-convert.md) - Automatic portfolio rebalancing with delegation
- [Fiat Payment Requests](docs/features/fiat-payment-system.md) - Payment request creation and management

### Backend & Testing
- [Jupiter Swap Integration](docs/backend/jupiter-swap.md) - Token swap implementation

### Third-Party Integrations
- [Helius Webhook Setup](docs/integrations/helius-webhook.md) - Auto-convert webhook configuration and testing

### Deployment
- [Go-Live Checklist](docs/deployment/go-live-checklist.md) - Production readiness checklist
- [Payment Request Deployment](docs/deployment/payment-requests.md) - Payment request system deployment

### Revenue & Monetization
- [Business Model](docs/monetization/business-model.md) - Revenue projections and fee structure
- [Platform Fees](docs/monetization/platform-fees.md) - Auto-convert platform fee setup (0.5%)

## Development

### Backend (Firebase Functions)

```bash
cd functions
npm install
npm run build

# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:sponsorJupiterSwap
```

### iOS App

```bash
open Wickett.xcodeproj
# Build & run in Xcode (⌘R)
```

### Monitoring

Fee payer wallet balance checked hourly via `monitorFeePayerBalance`.
**View logs:** Firebase Console → Functions → Logs

**Manual check:**
```bash
# Call from iOS app or admin panel
checkFeePayerBalance()
```

## Architecture

```
┌─────────────────────────────────────┐
│        WICKETT iOS APP              │
│  - Privy Auth (Apple/Google OAuth)  │
│  - User handles (@username)         │
│  - Multi-currency portfolio         │
│  - Send/receive payments            │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│    FIREBASE CLOUD FUNCTIONS         │
│  - Transaction sponsorship          │
│  - Jupiter swap integration         │
│  - Wallet monitoring                │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│       SOLANA BLOCKCHAIN             │
│  - SOL & SPL token transfers        │
│  - Jupiter swaps (0.8% fee)         │
│  - 400ms settlement, ~$0.00015 gas  │
└─────────────────────────────────────┘
                ↑↓
┌─────────────────────────────────────┐
│       COINBASE ONRAMP API           │
│  - Fiat on/off-ramp                 │
│  - Apple Pay integration            │
└─────────────────────────────────────┘
```

## Security

- ✅ No private keys in code (Firebase Secret Manager)
- ✅ Gas fee sponsorship (users pay $0)
- ✅ Automated balance monitoring (hourly checks)
- ✅ Firebase Security Rules configured
- ✅ Rate limiting (disabled for development, enable for production)

## Revenue Model

**0.8% all-in swap fee**
- Your direct fee: 0.55%
- Jupiter platform fee: 0.50%
  - Jupiter keeps: 0.25%
  - You get (referral): 0.25%
- **Total your revenue: 0.80%**

**Projected Revenue** (10,000 users, $250 avg swap, 10 swaps/month):
- Monthly volume: $25M
- Your revenue: $200,000/month
- Gas costs: -$18,000
- **Net profit: $182,000/month** ($2.18M/year)

See [docs/monetization/business-model.md](docs/monetization/business-model.md) for details.

## Environment Setup

### Required Secrets (Firebase Secret Manager)

```bash
# Helius RPC endpoint
firebase functions:secrets:set HELIUS_RPC_URL

# Fee payer wallet (for sponsoring gas)
firebase functions:secrets:set SOLANA_FEE_PAYER_PRIVATE_KEY

# Fee payer public key (for monitoring)
firebase functions:secrets:set SOLANA_FEE_PAYER_PUBLIC_KEY

# Privy app secret
firebase functions:secrets:set PRIVY_APP_SECRET

# Jupiter referral wallet (optional, for 0.25% kickback)
firebase functions:secrets:set JUPITER_REFERRAL_WALLET
```

## Roadmap

### ✅ Phase 1: Core Features (COMPLETE)
- ✅ Privy authentication with embedded wallets
- ✅ Wallet balance display with real-time pricing
- ✅ Send SOL/SPL tokens with user signing
- ✅ Gas sponsorship (zero fees for users)
- ✅ Backend V2 architecture with mainnet testing

### 🚧 Phase 2: User Testing (In Progress)
- [ ] TestFlight beta deployment
- [ ] User acceptance testing
- [ ] Bug fixes and UX improvements
- [ ] Firebase Remote Config setup for production

### 📋 Phase 3: Transaction History (Next)
- [ ] Transaction history display
- [ ] Recent recipients tracking
- [ ] Receive feature (QR codes, payment links)
- [ ] Address book / contacts

### 📋 Phase 4: Advanced Features
- [ ] User handle system (@username)
- [ ] Jupiter swap UI
- [ ] SNS .sol domain support
- [ ] Gold verification badges
- [ ] Portfolio charts and analytics

## Contributing

This is a private project. Contact the owner for contribution guidelines.

## Support

For issues or questions:
- Backend (Cloud Functions): Check Firebase Console logs
- iOS App: Open issue with Xcode build logs
- General: Contact project maintainer

## License

Proprietary - All rights reserved

---

Built with ⚡ on Solana | Powered by Firebase, Privy, Jupiter & Coinbase
