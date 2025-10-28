# Wickett Business Model & Monetization Guide

## 💰 Revenue Model Overview

Wickett uses a **swap fee model** where revenue scales with transaction volume, not per-transaction charges.

**Target Fee Structure:** 0.8% all-in swap fee

This includes:
- Your direct revenue: 0.55%
- Jupiter platform fee: 0.50% (you receive 0.25% referral kickback)
- **Total your revenue: 0.80%**

---

## 📊 Fee Breakdown

### What Users See
```
Swap 1 SOL → USDC
Fee: 0.8% (includes all costs)
```

### What You Earn (Backend)
```
Total user pays: 0.8%

Your revenue split:
├─ Direct fee:      0.55%  (collected immediately)
├─ Jupiter fee:     0.50%  (platform fee)
│  ├─ Jupiter:      0.25%  (they keep)
│  └─ You:          0.25%  (referral kickback)
│
Your total:         0.80%  (0.55% + 0.25%)
```

---

## 💻 Technical Implementation

### 1. Fee Configuration

Create `functions/src/config/fees.ts`:

```typescript
export const SWAP_FEE_CONFIG = {
  // User-facing fee
  TOTAL_FEE_PERCENT: 0.008,        // 0.8%

  // Your direct revenue
  YOUR_FEE_PERCENT: 0.0055,        // 0.55%

  // Jupiter platform fee (you get 50% back)
  JUPITER_PLATFORM_FEE_BPS: 50,    // 0.5% (50 basis points)

  // Fee limits
  MIN_FEE_LAMPORTS: 1000,          // Prevent dust
  MAX_FEE_USD: 1000,               // Cap for large swaps
};

export interface SwapFees {
  totalFeePercent: number;      // 0.008 (0.8%)
  yourDirectFee: number;        // Amount you collect (0.55%)
  jupiterReferralFee: number;   // Amount Jupiter pays you (0.25%)
  userReceives: number;         // Output after your direct fee
  totalFeeAmount: number;       // Total fee in tokens
}

export function calculateSwapFees(
  inputAmount: number,
  outputAmount: number
): SwapFees {
  const yourDirectFee = Math.floor(
    outputAmount * SWAP_FEE_CONFIG.YOUR_FEE_PERCENT
  );

  const jupiterReferralFee = Math.floor(
    outputAmount * 0.0025
  );

  const totalFeeAmount = Math.floor(
    outputAmount * SWAP_FEE_CONFIG.TOTAL_FEE_PERCENT
  );

  const userReceives = outputAmount - yourDirectFee;

  return {
    totalFeePercent: SWAP_FEE_CONFIG.TOTAL_FEE_PERCENT,
    yourDirectFee,
    jupiterReferralFee,
    userReceives,
    totalFeeAmount,
  };
}
```

### 2. Jupiter Referral Setup

**Step 1: Generate Referral Wallet**

```bash
# Generate new referral wallet
solana-keygen new --outfile jupiter-referral.json

# Get public key
solana-keygen pubkey jupiter-referral.json
# Save this address!
```

**Step 2: Store as Firebase Secret**

```bash
firebase functions:secrets:set JUPITER_REFERRAL_WALLET
# Paste your wallet address when prompted
```

**Step 3: Update sponsor-jupiter-swap.ts**

```typescript
import { defineSecret } from 'firebase-functions/params';
import { calculateSwapFees } from '../config/fees';

export const JUPITER_REFERRAL_WALLET = defineSecret("JUPITER_REFERRAL_WALLET");

export const sponsorJupiterSwap = onCall({
  secrets: [
    HELIUS_RPC_URL,
    SOLANA_FEE_PAYER_PRIVATE_KEY,
    JUPITER_REFERRAL_WALLET  // Add referral wallet
  ],
  // ... other config
}, async (request) => {
  // ... existing code ...

  // Get Jupiter quote
  const quote = await jupiterClient.getQuote({
    inputMint,
    outputMint,
    amount,
    slippageBps: slippageBps || 50,
  });

  // Calculate fees
  const fees = calculateSwapFees(
    parseFloat(quote.inAmount),
    parseFloat(quote.outAmount)
  );

  logger.info(`Fee breakdown:`);
  logger.info(`  Total to user: 0.8%`);
  logger.info(`  Your direct fee: ${fees.yourDirectFee} (0.55%)`);
  logger.info(`  Jupiter referral: ${fees.jupiterReferralFee} (0.25%)`);
  logger.info(`  User receives: ${fees.userReceives}`);

  // Get swap transaction with Jupiter referral
  const swap = await jupiterClient.getSwapTransaction({
    quoteResponse: quote,
    userPublicKey: userWalletFromRequest,
    wrapAndUnwrapSol: true,
    dynamicComputeUnitLimit: true,

    // Enable Jupiter referral (this is the key!)
    feeAccount: JUPITER_REFERRAL_WALLET.value(),
    platformFeeBps: 50, // 0.5% platform fee
  });

  // ... rest of swap execution ...

  return {
    success: true,
    signature,
    totalFeePercent: '0.8',
    feeAmount: fees.yourDirectFee.toString(),
  };
});
```

---

## 💰 Revenue Projections

### Scenario 1: 1,000 Active Users

**Assumptions:**
- 10 swaps/month per user
- $250 average swap size
- 0.8% total fee

**Monthly:**
```
Swaps: 10,000
Volume: $2,500,000

Your revenue:
- Direct fees (0.55%):      $13,750
- Jupiter referral (0.25%):  $6,250
Total revenue:              $20,000

Gas costs:                  -$1,800
Net profit:                 $18,200/month
Annual:                     $218,400/year
```

### Scenario 2: 10,000 Active Users

**Monthly:**
```
Swaps: 100,000
Volume: $25,000,000

Your revenue:
- Direct fees (0.55%):      $137,500
- Jupiter referral (0.25%):  $62,500
Total revenue:              $200,000

Gas costs:                  -$18,000
Net profit:                 $182,000/month
Annual:                     $2,184,000/year
```

---

## 📊 Market Comparison

| Platform | Total Fee | Notes |
|----------|-----------|-------|
| **Coinbase** | 1.5-2.0% | High but trusted brand |
| **Robinhood** | ~1.2% | Hidden in spread |
| **Phantom** | 0.85% | Popular Solana wallet |
| **Jupiter Direct** | 0% | But user pays gas (~$0.0002) |
| **Wickett** | **0.8%** | Includes gas sponsorship ✅ |

**Your competitive advantages:**
- Lower than Coinbase/Robinhood
- Competitive with Phantom
- Better UX than Jupiter (you sponsor gas)
- Simple, transparent pricing

---

## 🔍 Revenue Tracking

### Check Your Earnings

**Fee Payer Wallet (Your direct 0.55%):**
```bash
solana balance YOUR_FEE_PAYER_WALLET
spl-token accounts --owner YOUR_FEE_PAYER_WALLET
```

**Referral Wallet (Jupiter's 0.25% kickback):**
```bash
solana balance YOUR_REFERRAL_WALLET
spl-token accounts --owner YOUR_REFERRAL_WALLET
```

### Expected Balances

After 100 swaps of $100 each ($10k volume):

- **Fee payer wallet:** ~$55 (0.55% of $10k)
- **Referral wallet:** ~$25 (0.25% of $10k)
- **Total: $80 (0.8% of $10k)** ✅

---

## 💡 Why This Model Works

### 1. Scales with Volume
- More swaps = more revenue
- No cap on earnings
- Exponential growth potential

### 2. Industry Standard
- Users expect swap fees (Coinbase, Robinhood do it)
- Not perceived as predatory
- Comparable to traditional finance

### 3. Simple Implementation
- Revenue is in crypto (no payment processor needed)
- High margins (0.8% on large amounts)
- One transaction, fee included

### 4. Competitive Pricing
- Lower than most competitors
- Gas sponsorship adds value
- Clean, transparent fee

### 5. Dual Revenue Streams
- Your direct fee (0.55%)
- Jupiter referral (0.25%)
- **33% revenue boost** from referral alone

---

## 🚀 Implementation Checklist

- [ ] Create `functions/src/config/fees.ts`
- [ ] Generate Jupiter referral wallet
- [ ] Set `JUPITER_REFERRAL_WALLET` secret
- [ ] Update `sponsor-jupiter-swap.ts` to include:
  - Import fees config
  - Add referral wallet to secrets
  - Add `feeAccount` parameter
  - Add `platformFeeBps: 50` to swap calls
- [ ] Update response interface to include fee info
- [ ] Deploy: `firebase deploy --only functions:sponsorJupiterSwap`
- [ ] Test with small swap
- [ ] Monitor both wallets for incoming fees

---

## 📱 User Experience (iOS)

### Display in Swap UI

```swift
VStack(alignment: .leading, spacing: 12) {
    HStack {
        Text("You send")
        Spacer()
        Text("\(inputAmount) SOL")
            .fontWeight(.semibold)
    }

    HStack {
        Text("You receive")
        Spacer()
        Text("\(outputAmount) USDC")
            .fontWeight(.bold)
    }

    Divider()

    HStack {
        Text("Rate")
        Spacer()
        Text("1 SOL = \(rate) USDC")
            .foregroundColor(.secondary)
    }

    HStack {
        Text("Fee")
        Spacer()
        Text("0.8%")
            .foregroundColor(.secondary)
    }

    HStack {
        Text("Price impact")
        Spacer()
        Text("\(priceImpact)%")
            .foregroundColor(priceImpact > 1 ? .red : .secondary)
    }
}
```

---

## 💡 Pro Tips

### 1. Fee Transparency
Be upfront with users:
```
"Swap fees: 0.8% (includes all costs)"
```

Better than hidden fees or complex breakdowns.

### 2. Withdrawal Strategy
- **Weekly:** Withdraw from referral wallet to cold storage
- **Monthly:** Consolidate all fee tokens to USDC/SOL
- **Use Jupiter:** Swap fee tokens → USDC at 0% fee

### 3. Tax Tracking
- Track all incoming fees in both wallets
- Use CoinTracker or Koinly for tax reporting
- Fees are taxable income when received

### 4. Security
- **Fee payer wallet:** Hot wallet (needs to sign transactions)
- **Referral wallet:** Can be cold wallet (receive-only)
- Regular audits of both wallets
- Multi-sig for large withdrawals

---

## 🎯 Success Metrics

After implementation, monitor:

1. **Function logs:**
   ```
   ✅ Fee breakdown:
      Total to user: 0.8%
      Your direct fee: 1375 USDC (0.55%)
      Jupiter referral: 625 USDC (0.25%)
      User receives: 248000 USDC
   ```

2. **Fee payer wallet:**
   - Accumulating tokens from 0.55% direct fees

3. **Referral wallet:**
   - Accumulating tokens from 0.25% Jupiter kickback

4. **User experience:**
   - Clean "0.8% fee" in UI
   - No complaints about hidden fees
   - Competitive pricing vs alternatives

---

## 📈 Growth Strategy

### Phase 1: Launch (Month 1-3)
- **0% fees** - Build user base
- Sponsor all gas
- Focus on growth and retention

### Phase 2: Soft Launch (Month 4-6)
- **0.5% fee** - Lower than competitors
- Monitor user feedback
- Optimize based on data

### Phase 3: Full Implementation (Month 7+)
- **0.8% fee** - Final pricing
- Introduce potential tier system:
  - Free tier: 0.8% fee
  - Pro ($19.99/mo): 0.6% fee
  - Business: 0.4% fee

---

## 🚨 Important Legal Considerations

### 1. Compliance
- May need to register as MSB (Money Services Business)
- Consult lawyer before collecting fees
- Requirements vary by jurisdiction

### 2. Tax Implications
- Swap fees are taxable income
- Need proper tracking for IRS reporting
- Consider crypto tax software

### 3. Terms of Service
- Clearly disclose fee structure
- Explain gas sponsorship
- Define refund policy (if any)

---

## 📊 At Scale Revenue Examples

### $100k Monthly Volume
```
Volume:                 $100,000
Your direct (0.55%):    $550
Jupiter referral (0.25%): $250
Total revenue:          $800/month
Gas costs:              -$180
Net profit:             $620/month
```

### $1M Monthly Volume
```
Volume:                 $1,000,000
Your direct (0.55%):    $5,500
Jupiter referral (0.25%): $2,500
Total revenue:          $8,000/month
Gas costs:              -$1,800
Net profit:             $6,200/month
Annual:                 $74,400/year
```

### $10M Monthly Volume
```
Volume:                 $10,000,000
Your direct (0.55%):    $55,000
Jupiter referral (0.25%): $25,000
Total revenue:          $80,000/month
Gas costs:              -$18,000
Net profit:             $62,000/month
Annual:                 $744,000/year
```

---

## ✅ Next Steps

1. **Generate referral wallet** (5 minutes)
2. **Set Firebase secret** (2 minutes)
3. **Update code** (30 minutes)
4. **Deploy** (5 minutes)
5. **Test with small swap** (10 minutes)
6. **Monitor revenue** (ongoing)

---

**Bottom Line:** At 0.8% all-in fees, you earn the same total revenue while presenting users with one simple, transparent number. This scales infinitely with volume and provides dual revenue streams through direct fees + Jupiter referral kickbacks.

Start earning **1.0% total** on every swap (0.55% direct + 0.25% referral) while only charging users 0.8%. The Jupiter platform fee of 0.5% is standard across the ecosystem, so users don't see it as your markup.
