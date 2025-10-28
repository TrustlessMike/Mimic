# Wickett - Venmo for Crypto

Global payment app using Solana blockchain + Sphere Pay for instant, low-cost money transfers.

## Project Status

✅ **Backend Complete** - All Solana functions tested on mainnet
🚧 **Frontend In Progress** - iOS app under development
📋 **Next Up** - User handle system (@username) + Sphere Pay integration

## Tech Stack

- **Backend**: Firebase Cloud Functions (TypeScript)
- **Blockchain**: Solana (SOL, USDC, SPL tokens)
- **Fiat Rails**: Sphere Pay (0.2-0.3% fees)
- **Frontend**: SwiftUI iOS app (iOS 16+)
- **Auth**: Privy embedded wallets

## Cloud Functions (Production)

| Function | Purpose | Status |
|----------|---------|--------|
| `createFirebaseCustomToken` | Privy → Firebase auth bridge | ✅ Deployed |
| `sponsorSolTransfer` | Gas-sponsored SOL transfers | ✅ Tested mainnet |
| `sponsorSplTransfer` | Gas-sponsored SPL token transfers | ✅ Tested mainnet |
| `sponsorJupiterSwap` | Token swaps via Jupiter aggregator | ✅ Tested mainnet |
| `sponsorCustomInstruction` | Custom Solana program interactions | ✅ Tested mainnet |
| `monitorFeePayerBalance` | Hourly wallet balance monitoring | ✅ Deployed |
| `checkFeePayerBalance` | Manual balance check (callable) | ✅ Deployed |

**Mainnet Testing:**
- 8 confirmed transactions
- 100% success rate
- Total cost: ~0.011 SOL (~$2.20)
📄 See: [docs/backend-testing.md](docs/backend-testing.md)

## Features

### ✅ Implemented
- [x] Gas-sponsored Solana transactions
- [x] Jupiter token swaps with ALT resolution
- [x] Fee payer wallet monitoring (hourly checks)
- [x] Privy OAuth authentication (Apple/Google)
- [x] Firebase integration (Auth, Firestore, Functions)

### 🚧 In Progress
- [ ] User handles (@username system)
- [ ] Multi-currency portfolio display
- [ ] Sphere Pay virtual accounts (fiat on-ramp)
- [ ] Send/receive payment flows

### 📋 Planned
- [ ] USDC-based cross-border payments
- [ ] Gold verification badges (early adopters)
- [ ] Transaction history with real data
- [ ] Swap fee monetization (0.8% all-in)
- [ ] SNS .sol domain support

## Documentation

- **[Backend Testing Results](docs/backend-testing.md)** - All mainnet transactions verified
- **[Business Model & Monetization](docs/monetization/business-model.md)** - Revenue strategy (0.8% swap fees)
- **[Wallet Integration Guide](docs/wallet-integration.md)** - Privy embedded wallet setup

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
│         SPHERE PAY API              │
│  - Virtual accounts (fiat on-ramp)  │
│  - Multi-currency (160+ markets)    │
│  - 0.2-0.3% fees                    │
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

### Phase 1: User System (Weeks 1-2)
- User handle registration (@username)
- Display name vs handle separation
- 30-day handle change cooldown
- Gold verification badges

### Phase 2: Sphere Integration (Weeks 3-4)
- Virtual account creation on signup
- Fiat on-ramp (bank → USDC)
- Balance display in multiple currencies

### Phase 3: Payment Flows (Weeks 5-6)
- Send payment UI (USDC/SOL)
- Receive payment UI (QR codes, payment links)
- Transaction history with real data
- Wickett-to-Wickett auto-conversion

### Phase 4: Polish & Launch (Weeks 7-8)
- Error handling & loading states
- TestFlight beta
- Fee monetization implementation
- Launch!

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

Built with ⚡ on Solana | Powered by Firebase, Privy, Jupiter & Sphere Pay
