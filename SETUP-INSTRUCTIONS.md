# Wickett Solana Transaction Backend Setup Instructions

## Overview
This backend enables sponsored (gasless) Solana transactions for your Wickett app, including SOL transfers, SPL token transfers, Jupiter swaps, and custom program interactions.

## Prerequisites
- Node.js 18+ installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- Solana CLI installed (for generating keypair)

## Setup Steps

### 1. Generate Fee Payer Wallet

First, generate a new Solana keypair that will pay for all transaction fees:

```bash
# Generate a new keypair
solana-keygen new --outfile fee-payer-keypair.json

# Get the public key
solana-keygen pubkey fee-payer-keypair.json

# Get the private key in base58 format
cat fee-payer-keypair.json | jq -r '. | @base64d | split("") | map(tostring) | join(",")'
```

Alternatively, use this Node.js script:

```javascript
const { Keypair } = require("@solana/web3.js");
const bs58 = require("bs58");

// Generate new keypair
const keypair = Keypair.generate();

console.log("Public Key:", keypair.publicKey.toBase58());
console.log("Private Key (base58):", bs58.encode(keypair.secretKey));
```

**IMPORTANT**: Store the private key securely! Never commit it to version control.

### 2. Fund the Fee Payer Wallet

Transfer 5-10 SOL to the fee payer public key on mainnet:

```bash
# Check balance
solana balance <YOUR_FEE_PAYER_PUBLIC_KEY> --url mainnet-beta
```

### 3. Configure Firebase Secrets

Set up the required secrets in Firebase:

```bash
# Navigate to functions directory
cd functions

# Set Helius RPC URL
firebase functions:secrets:set HELIUS_RPC_URL
# When prompted, enter: https://mainnet.helius-rpc.com/?api-key=02e56c48-a395-4cfd-956e-32189ad3c643

# Set fee payer private key
firebase functions:secrets:set SOLANA_FEE_PAYER_PRIVATE_KEY
# When prompted, enter the base58-encoded private key from step 1
```

### 4. Install Dependencies

```bash
# In the functions directory
cd functions
npm install
```

### 5. Build and Test Locally

```bash
# Build TypeScript
npm run build

# Test locally with emulator
npm run serve
```

### 6. Deploy to Firebase

```bash
# Deploy all functions
npm run deploy

# Or deploy specific function
firebase deploy --only functions:sponsorSolTransfer
```

## Available Functions

### 1. `sponsorSolTransfer`
Transfer SOL from user's wallet to another address (gas sponsored by backend).

**Request:**
```typescript
{
  destinationAddress: string;  // Recipient's Solana address
  amountLamports: number;     // Amount in lamports (1 SOL = 1e9 lamports)
  memo?: string;              // Optional memo
}
```

**Response:**
```typescript
{
  success: boolean;
  signature?: string;         // Transaction signature
  explorerUrl?: string;       // Solscan URL
  error?: string;
  code?: string;
}
```

### 2. `sponsorSplTransfer`
Transfer SPL tokens (USDC, USDT, etc.) from user's wallet to another address.

**Request:**
```typescript
{
  tokenMintAddress: string;          // Token mint address
  destinationAddress: string;        // Recipient's address
  amount: number;                    // Amount in smallest unit
  decimals: number;                  // Token decimals
  createDestinationATA?: boolean;    // Auto-create destination token account
}
```

### 3. `sponsorJupiterSwap`
Swap tokens using Jupiter aggregator (best price routing).

**Request:**
```typescript
{
  inputMint: string;          // Token to swap from
  outputMint: string;         // Token to swap to
  amount: number;             // Amount in smallest unit
  slippageBps?: number;       // Slippage (default: 50 = 0.5%)
  onlyDirectRoutes?: boolean; // Only direct routes
}
```

### 4. `sponsorCustomInstruction`
Execute custom program instructions (whitelisted programs only).

**Request:**
```typescript
{
  instructions: Array<{
    programId: string;
    accounts: Array<{
      pubkey: string;
      isSigner: boolean;
      isWritable: boolean;
    }>;
    data: number[];  // Instruction data as byte array
    memo?: string;
  }>;
}
```

## Security Configuration

### Rate Limiting
- Max 50 transactions per user per day
- Max 0.1 SOL per transaction
- Max 10 SOL daily budget across all users

### Whitelisted Programs
The following programs are whitelisted for custom instructions:
- System Program
- SPL Token Program
- Token-2022 (Token Extensions)
- Jupiter V6 & V4
- Associated Token Program

To add more programs, edit `functions/src/solana-config.ts`:

```typescript
export const WHITELISTED_PROGRAM_IDS = new Set<string>([
  "YOUR_PROGRAM_ID_HERE",
  // ... existing programs
]);
```

## Monitoring & Maintenance

### Check Fee Payer Balance

```bash
# View current balance
firebase functions:log --only sponsorSolTransfer

# Or use Solana CLI
solana balance <FEE_PAYER_PUBLIC_KEY> --url mainnet-beta
```

### View Transaction Logs

```bash
# View all function logs
firebase functions:log

# View specific function logs
firebase functions:log --only sponsorJupiterSwap
```

### Transaction History

All transactions are logged to Firestore in the `transactions` collection:

```typescript
{
  userId: string;
  type: string;
  amount: number;
  status: "pending" | "success" | "failed";
  timestamp: Timestamp;
  signature?: string;
  metadata?: object;
}
```

## Common Token Mints (for reference)

```typescript
SOL:  "So11111111111111111111111111111111111111112"
USDC: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
USDT: "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB"
BONK: "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263"
```

## Troubleshooting

### Error: "Fee payer wallet not found"
- Ensure `SOLANA_FEE_PAYER_PRIVATE_KEY` secret is set correctly
- Verify the private key is in base58 format

### Error: "Insufficient balance"
- Check fee payer wallet balance
- Transfer more SOL to fee payer address

### Error: "Program not whitelisted"
- Add the program ID to `WHITELISTED_PROGRAM_IDS` in `solana-config.ts`
- Redeploy functions

### Error: "Rate limit exceeded"
- User has hit daily transaction limit (50/day)
- Wait 24 hours or increase limit in `solana-config.ts`

## iOS Integration (Coming Soon)

Once the backend is deployed, you'll integrate with your iOS app using:

```swift
import Solana

// Example: Call sponsor SOL transfer
let result = try await firebaseCallable.call("sponsorSolTransfer", data: [
    "destinationAddress": destinationAddress,
    "amountLamports": amountInLamports
])
```

## Support

For issues or questions:
- Check Firebase Functions logs
- Review Solscan for transaction details
- Verify Helius RPC is responding

## Next Steps

1. ✅ Deploy backend functions
2. ⏳ Implement iOS Solana transaction service
3. ⏳ Wire up UI to call backend functions
4. ⏳ Test end-to-end on mainnet with small amounts
5. ⏳ Monitor and optimize
