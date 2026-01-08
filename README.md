<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0+-blue?logo=apple" alt="iOS 17.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Solana-Mainnet-purple?logo=solana" alt="Solana">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

<h1 align="center">Mimic</h1>

<p align="center">
  <strong>Follow top traders. Copy their moves.</strong>
</p>

<p align="center">
  See what successful traders are buying—and copy them with one tap.<br>
  No charts. No research. Just follow the smart money.
</p>

---

## Overview

Mimic lets you follow successful traders and copy their moves with one tap. No experience needed—just pick who to follow and let the app do the rest.

**Key Features:**
- **Follow Anyone** - Add traders to see what they're buying
- **Real-Time Feed** - See trades as they happen
- **One-Tap Copy** - Execute the same trade instantly
- **Safe by Default** - Only established assets allowed
- **Degen Mode** - Opt-in for higher-risk opportunities

## Safety Model

Copy trading can be risky. Mimic protects you by default.

| Mode | What's Allowed | Description |
|------|----------------|-------------|
| **Safe Mode** | Major established assets | Default for all users |
| **Degen Mode** | Everything | Opt-in for experienced users |

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
│   └── Mimic/
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
2. Open `Mimic.xcodeproj` in Xcode
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
