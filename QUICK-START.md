# Quick Start Guide - Solana Transaction Backend

## ⚡ 5-Minute Setup

### Step 1: Install Dependencies (1 min)
```bash
cd functions
npm install
```

### Step 2: Generate Fee Payer Wallet (1 min)
```bash
# Install Solana CLI if not already installed
# brew install solana (macOS)

# Generate keypair
solana-keygen new --outfile ~/.config/solana/wickett-fee-payer.json

# Get public key (save this - you'll need to fund it)
solana-keygen pubkey ~/.config/solana/wickett-fee-payer.json

# Get private key in base58 format
# Use this Node.js script:
node -e "const { Keypair } = require('@solana/web3.js'); const bs58 = require('bs58'); const fs = require('fs'); const kp = Keypair.fromSecretKey(new Uint8Array(JSON.parse(fs.readFileSync(process.env.HOME + '/.config/solana/wickett-fee-payer.json')))); console.log(bs58.encode(kp.secretKey));"
```

### Step 3: Fund Fee Payer (2 min)
```bash
# Transfer 5-10 SOL to the public key from step 2
# You can use Phantom, Solflare, or any Solana wallet

# Verify balance
solana balance <YOUR_PUBLIC_KEY> --url mainnet-beta
```

### Step 4: Set Firebase Secrets (1 min)
```bash
# Set Helius RPC URL
firebase functions:secrets:set HELIUS_RPC_URL
# Enter when prompted: https://mainnet.helius-rpc.com/?api-key=02e56c48-a395-4cfd-956e-32189ad3c643

# Set fee payer private key (base58 from step 2)
firebase functions:secrets:set SOLANA_FEE_PAYER_PRIVATE_KEY
# Enter the base58 private key when prompted
```

### Step 5: Deploy (1 min)
```bash
cd functions
npm run deploy
```

## ✅ You're Done!

Your backend is now live with 4 Solana transaction functions:
- `sponsorSolTransfer` - Transfer SOL
- `sponsorSplTransfer` - Transfer tokens (USDC, USDT, etc.)
- `sponsorJupiterSwap` - Swap tokens via Jupiter
- `sponsorCustomInstruction` - Custom program interactions

## 🧪 Test It

### Option 1: Use Firebase Console
1. Go to Firebase Console → Functions
2. Select `sponsorSolTransfer`
3. Test with:
```json
{
  "destinationAddress": "YOUR_TEST_ADDRESS",
  "amountLamports": 1000000
}
```

### Option 2: Call from iOS App
```swift
let result = try await FirebaseCallableClient.shared.call(
    "sponsorSolTransfer",
    data: [
        "destinationAddress": testAddress,
        "amountLamports": 1_000_000 // 0.001 SOL
    ]
)
```

## 📊 Monitor

### Check Fee Payer Balance
```bash
solana balance <YOUR_FEE_PAYER_PUBLIC_KEY> --url mainnet-beta
```

### View Logs
```bash
firebase functions:log
```

### View Transactions
Check Firestore → `transactions` collection

## 🔧 Troubleshooting

### "Function not found"
- Run `firebase deploy --only functions` again
- Check Firebase Console → Functions tab

### "Secret not found"
- Verify secrets are set: `firebase functions:secrets:access HELIUS_RPC_URL`
- Re-run `firebase functions:secrets:set` if needed

### "Insufficient funds"
- Check fee payer balance
- Transfer more SOL to fee payer address

## 📚 Next Steps

1. Read [IMPLEMENTATION-SUMMARY.md](./IMPLEMENTATION-SUMMARY.md) for full details
2. Read [SETUP-INSTRUCTIONS.md](./SETUP-INSTRUCTIONS.md) for advanced configuration
3. Implement iOS integration
4. Build transaction UI
5. Test with real users!

## 💰 Cost Estimates

### Solana Transaction Costs (paid by your fee payer):
- SOL transfer: ~0.000005 SOL ($0.0007)
- SPL token transfer: ~0.00001 SOL ($0.0014)
- Jupiter swap: ~0.00002-0.0001 SOL ($0.003-0.014)
- Custom instruction: ~0.00001-0.0001 SOL (varies)

### With 10 SOL in fee payer:
- Can sponsor ~2 million SOL transfers
- Can sponsor ~1 million token transfers
- Can sponsor ~100,000-500,000 swaps

### Firebase Costs:
- Functions: Pay-as-you-go (generous free tier)
- Firestore: Free tier should cover logging for most apps
- Secrets Manager: First 10,000 accesses/month free

## 🚀 Performance

- Average confirmation time: 2-5 seconds
- Success rate: >95% (with proper RPC)
- Concurrent transactions: Limited by Firebase Functions scaling
- Rate limiting: 50 tx/user/day (configurable)

## 🎉 You're All Set!

Your Solana transaction backend is now live and ready to power gasless transactions for your users!
