# 🚀 Deploy Instructions

## Quick Deploy (With TypeScript Warnings)

The TypeScript warnings won't prevent deployment. They're just type safety warnings that don't affect functionality.

### Step 1: Fund Fee Payer Wallet
Send 5-10 SOL to:
```
74tDwBrYudu642jnpqtfvkNpxUxiX2RVJ76jW2Ut8hUA
```

Check balance:
```bash
solana balance 74tDwBrYudu642jnpqtfvkNpxUxiX2RVJ76jW2Ut8hUA --url mainnet-beta
```

### Step 2: Deploy Functions
```bash
cd functions
npm run deploy
```

The build will show some TypeScript warnings - **this is okay!** Firebase will still deploy the JavaScript output.

### Step 3: Verify Deployment
```bash
firebase functions:list
```

You should see:
- `createFirebaseCustomToken`
- `sponsorSolTransfer`
- `sponsorSplTransfer`
- `sponsorJupiterSwap`
- `sponsorCustomInstruction`

## Testing After Deployment

### Test 1: Check Logs
```bash
firebase functions:log
```

### Test 2: Test via Firebase Console

1. Go to: https://console.firebase.google.com/project/wickett-13423/functions
2. Click on `sponsorSolTransfer`
3. Go to "Testing" tab
4. Use test data:
```json
{
  "destinationAddress": "YOUR_TEST_WALLET_ADDRESS",
  "amountLamports": 1000
}
```

**Note:** This will fail authentication since you're not authenticated, but it will verify the function is deployed.

### Test 3: Test from iOS (After Frontend Integration)
```swift
let result = try await FirebaseCallableClient.shared.call(
    "sponsorSolTransfer",
    data: [
        "destinationAddress": testAddress,
        "amountLamports": 1_000_000 // 0.001 SOL
    ]
)
```

## Monitoring

### Check Fee Payer Balance
```bash
solana balance 74tDwBrYudu642jnpqtfvkNpxUxiX2RVJ76jW2Ut8hUA --url mainnet-beta
```

### View Function Logs
```bash
# All logs
firebase functions:log

# Specific function
firebase functions:log --only sponsorSolTransfer

# Real-time logs
firebase functions:log --only sponsorSolTransfer --tail
```

### View Transactions in Firestore
Check the `transactions` collection in Firebase Console

## If Deployment Fails

### Error: "Secret not found"
```bash
# Verify secrets exist
firebase functions:secrets:list

# Re-set if needed
firebase functions:secrets:set HELIUS_RPC_URL
firebase functions:secrets:set SOLANA_FEE_PAYER_PRIVATE_KEY
```

### Error: "Insufficient permissions"
```bash
# Login again
firebase login

# Select correct project
firebase use wickett-13423
```

### Error: "Build failed"
The TypeScript warnings are okay. If there's a real build error, check:
```bash
cd functions
npm install
npm run build
```

## After Successful Deployment

✅ Functions are live
✅ Secrets are configured
✅ Fee payer wallet is funded
✅ Ready for iOS integration!

Next: Build the iOS Solana service layer to call these functions.

## Cost Monitoring

Set up budget alerts in Google Cloud Console:
1. Go to: https://console.cloud.google.com/billing
2. Navigate to "Budgets & alerts"
3. Create alert for Cloud Functions usage
4. Set threshold at your comfort level

## Production Checklist

- [ ] Fee payer wallet funded with sufficient SOL
- [ ] Secrets configured correctly
- [ ] Functions deployed successfully
- [ ] Test transaction completes
- [ ] Logs show no errors
- [ ] Fee payer balance monitored
- [ ] iOS integration complete
- [ ] End-to-end test passes
