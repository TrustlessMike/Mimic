<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0+-blue?logo=apple" alt="iOS 17.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Solana-Mainnet-purple?logo=solana" alt="Solana">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

<h1 align="center">Mimic</h1>

<p align="center">
  <strong>Track smart money. Copy their trades. Trade like the best.</strong>
</p>

<p align="center">
  A mobile-first Solana wallet tracker and copy trading app.<br>
  Follow elite traders, see their moves in real-time, and execute with one tap.
</p>

---

## Overview

Mimic is an iOS app that lets you track any Solana wallet and copy their trades instantly. Built for traders who want to follow smart money without the complexity.

**Key Features:**
- **Wallet Tracking** - Add any Solana address to monitor their trades
- **Real-Time Feed** - See swaps as they happen via Helius webhooks
- **One-Tap Copy** - Execute the same trade with a single button
- **Safe by Default** - Only major tokens allowed (SOL, USDC, ETH, etc.)
- **Degen Mode** - Opt-in to copy memecoin/pumpfun trades

## Safety Model

Most copy traders lose money chasing memecoins. Mimic protects you by default.

| Mode | Tokens | Description |
|------|--------|-------------|
| **Safe Mode** | SOL, USDC, USDT, ETH, wBTC, JUP, BONK, WIF | Default for all users |
| **Degen Mode** | All tokens | Opt-in for experienced traders |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS App                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   Feed   │  │ Discover │  │Portfolio │  │ Settings │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Firebase Functions                        │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────────┐ │
│  │ Wallet Tracker │  │ Trade Webhook  │  │  Copy Trading │ │
│  └────────────────┘  └────────────────┘  └───────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
    ┌──────────┐        ┌──────────┐        ┌──────────┐
    │  Helius  │        │  Jupiter │        │  Privy   │
    │ Webhooks │        │   Swap   │        │   Auth   │
    └──────────┘        └──────────┘        └──────────┘
```

## Tech Stack

**iOS App:**
- SwiftUI + Swift 5.9
- Privy SDK (wallet auth + signing)
- Firebase SDK

**Backend:**
- Firebase Cloud Functions (TypeScript)
- Firestore Database
- Helius Webhooks (transaction monitoring)
- Jupiter Aggregator (swap execution)

**Infrastructure:**
- Solana Mainnet
- Coinbase Onramp/Offramp

## Project Structure

```
Mimic/
├── Sources/
│   └── Wickett/
│       ├── App/                    # App entry point
│       ├── Core/
│       │   ├── Authentication/     # Privy integration
│       │   ├── Coinbase/          # On/off ramp
│       │   ├── Navigation/        # Tab bar + routing
│       │   ├── Notifications/     # Push notifications
│       │   ├── Onboarding/        # User onboarding
│       │   └── Solana/            # Wallet + signing
│       ├── Features/
│       │   ├── Auth/              # Login views
│       │   ├── Feed/              # Trade feed + tracking
│       │   ├── Coinbase/          # Funding views
│       │   ├── Settings/          # User preferences
│       │   ├── Swap/              # Token swaps
│       │   └── Wallet/            # Portfolio view
│       └── Shared/                # Models + components
├── functions/                     # Firebase Cloud Functions
│   └── src/
│       ├── tracking/              # Wallet tracking logic
│       ├── webhooks/              # Helius webhook handlers
│       └── utils/                 # Shared utilities
└── Resources/                     # Assets + config
```

## Getting Started

### Prerequisites

- Xcode 15+
- iOS 17.0+ device or simulator
- Node.js 18+ (for Firebase functions)
- Firebase CLI

### iOS Setup

1. Clone the repository
2. Open `Wickett.xcodeproj` in Xcode
3. Resolve Swift Package Manager dependencies
4. Build and run

### Firebase Setup

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

## Environment

Firebase secrets are managed via Firebase Functions secrets. No local `.env` files required for production.

Required secrets:
- `HELIUS_API_KEY` - Helius RPC + webhooks
- `PRIVY_APP_ID` - Privy authentication
- `PRIVY_APP_SECRET` - Privy server auth
- `COINBASE_APP_ID` - Coinbase onramp

## Roadmap

- [x] Wallet tracking with Helius webhooks
- [x] Real-time trade feed
- [x] One-tap copy trading
- [x] Safe Mode / Degen Mode
- [ ] Copy bots (auto-follow rules)
- [ ] Trader leaderboards
- [ ] Trade analytics

## License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  Built with Solana + SwiftUI
</p>
