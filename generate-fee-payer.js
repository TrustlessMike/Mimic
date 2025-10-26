#!/usr/bin/env node

const { Keypair } = require("@solana/web3.js");
const bs58 = require("bs58");
const fs = require("fs");

console.log("🔑 Generating Solana Fee Payer Wallet...\n");

// Generate new keypair
const keypair = Keypair.generate();

// Get keys
const publicKey = keypair.publicKey.toBase58();
const privateKeyBase58 = bs58.encode(keypair.secretKey);

console.log("✅ Wallet Generated Successfully!\n");
console.log("=" .repeat(80));
console.log("PUBLIC KEY (Fund this with 5-10 SOL):");
console.log("=" .repeat(80));
console.log(publicKey);
console.log("\n");

console.log("=" .repeat(80));
console.log("PRIVATE KEY (Base58 - Keep this SECRET!):");
console.log("=" .repeat(80));
console.log(privateKeyBase58);
console.log("\n");

// Save to file (optional)
const walletData = {
  publicKey,
  privateKeyBase58,
  secretKey: Array.from(keypair.secretKey),
};

const filename = `fee-payer-wallet-${Date.now()}.json`;
fs.writeFileSync(filename, JSON.stringify(walletData, null, 2));

console.log("=" .repeat(80));
console.log(`💾 Wallet saved to: ${filename}`);
console.log("=" .repeat(80));
console.log("\n");

console.log("📋 NEXT STEPS:");
console.log("1. Fund the PUBLIC KEY with 5-10 SOL on mainnet");
console.log("2. Run: firebase functions:secrets:set SOLANA_FEE_PAYER_PRIVATE_KEY");
console.log("3. Paste the PRIVATE KEY (Base58) when prompted");
console.log("4. Delete this file after setting the secret!");
console.log("\n");

console.log("⚠️  SECURITY WARNING:");
console.log(`   Delete ${filename} after you've set the Firebase secret!`);
console.log(`   Never commit this file to git!`);
