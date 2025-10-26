#!/usr/bin/env node

/**
 * Mainnet Live Transaction Test
 * Tests all 4 Solana functions with real authenticated transactions
 */

const admin = require('firebase-admin');
const { Keypair } = require('@solana/web3.js');

// Initialize Firebase Admin
const serviceAccount = require('./wickett-13423-firebase-adminsdk-t5fgj-28e4f30eea.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wickett-13423'
});

const PRIVY_USER_ID = 'privy_did:privy:cmh87nmms00rblb0dnjv8yqhj';

/**
 * Create custom token for testing
 */
async function getCustomToken() {
  try {
    const token = await admin.auth().createCustomToken(PRIVY_USER_ID);
    return token;
  } catch (error) {
    console.error('Error creating custom token:', error);
    throw error;
  }
}

/**
 * Sign in with custom token to get ID token
 */
async function signInWithCustomToken(customToken) {
  const https = require('https');

  const postData = JSON.stringify({
    token: customToken,
    returnSecureToken: true
  });

  const options = {
    hostname: 'identitytoolkit.googleapis.com',
    port: 443,
    path: '/v1/accounts:signInWithCustomToken?key=AIzaSyChRZQZjX0Q8EzhTNMBHxNVYNJuWEhxKS0',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        const data = JSON.parse(body);
        if (data.idToken) {
          resolve(data.idToken);
        } else {
          reject(new Error('Failed to get ID token: ' + body));
        }
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

/**
 * Call Firebase Function with auth
 */
async function callFunction(functionName, data, idToken) {
  const https = require('https');

  const postData = JSON.stringify({ data });

  const options = {
    hostname: 'us-central1-wickett-13423.cloudfunctions.net',
    port: 443,
    path: `/${functionName}`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${idToken}`,
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          body: body
        });
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

/**
 * Test 1: SOL Transfer
 */
async function testSolTransfer(idToken) {
  console.log('\n📍 Test 1: SOL Transfer');
  console.log('=' .repeat(80));

  const testWallet = Keypair.generate();
  console.log(`Destination: ${testWallet.publicKey.toBase58()}`);
  console.log('Amount: 1,000 lamports (0.000001 SOL)');

  try {
    const response = await callFunction('sponsorSolTransfer', {
      destinationAddress: testWallet.publicKey.toBase58(),
      amountLamports: 1000,
      userWalletAddress: Keypair.generate().publicKey.toBase58()
    }, idToken);

    console.log(`Status: ${response.statusCode}`);
    const result = JSON.parse(response.body);

    if (result.result && result.result.success) {
      console.log('✅ SUCCESS!');
      console.log(`Signature: ${result.result.signature}`);
      console.log(`Explorer: ${result.result.explorerUrl}`);
    } else {
      console.log('⚠️  Response:', JSON.stringify(result, null, 2));
    }
  } catch (error) {
    console.log('❌ Error:', error.message);
  }
}

/**
 * Test 2: SPL Transfer
 */
async function testSplTransfer(idToken) {
  console.log('\n📍 Test 2: SPL Token Transfer (USDC)');
  console.log('=' .repeat(80));

  const testWallet = Keypair.generate();
  console.log(`Destination: ${testWallet.publicKey.toBase58()}`);
  console.log('Token: USDC');
  console.log('Amount: 1,000 (0.001 USDC)');

  try {
    const response = await callFunction('sponsorSplTransfer', {
      destinationAddress: testWallet.publicKey.toBase58(),
      tokenMintAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', // USDC
      amount: 1000,
      userWalletAddress: Keypair.generate().publicKey.toBase58()
    }, idToken);

    console.log(`Status: ${response.statusCode}`);
    const result = JSON.parse(response.body);

    if (result.result && result.result.success) {
      console.log('✅ SUCCESS!');
      console.log(`Signature: ${result.result.signature}`);
      console.log(`Explorer: ${result.result.explorerUrl}`);
    } else {
      console.log('⚠️  Response:', JSON.stringify(result, null, 2));
    }
  } catch (error) {
    console.log('❌ Error:', error.message);
  }
}

/**
 * Test 3: Jupiter Swap Quote
 */
async function testJupiterSwap(idToken) {
  console.log('\n📍 Test 3: Jupiter Swap (SOL → USDC)');
  console.log('=' .repeat(80));

  console.log('Input: SOL');
  console.log('Output: USDC');
  console.log('Amount: 0.001 SOL');

  try {
    const response = await callFunction('sponsorJupiterSwap', {
      inputMint: 'So11111111111111111111111111111111111111112', // SOL
      outputMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', // USDC
      amount: 1000000, // 0.001 SOL
      userWalletAddress: Keypair.generate().publicKey.toBase58(),
      slippageBps: 50
    }, idToken);

    console.log(`Status: ${response.statusCode}`);
    const result = JSON.parse(response.body);

    if (result.result && result.result.success) {
      console.log('✅ SUCCESS!');
      console.log(`Signature: ${result.result.signature}`);
      console.log(`Explorer: ${result.result.explorerUrl}`);
    } else {
      console.log('⚠️  Response:', JSON.stringify(result, null, 2));
    }
  } catch (error) {
    console.log('❌ Error:', error.message);
  }
}

/**
 * Test 4: Custom Instruction (System Program Transfer)
 */
async function testCustomInstruction(idToken) {
  console.log('\n📍 Test 4: Custom Instruction (System Transfer)');
  console.log('=' .repeat(80));

  const testWallet = Keypair.generate();
  console.log(`Destination: ${testWallet.publicKey.toBase58()}`);

  // Create a simple system transfer instruction
  const instruction = {
    programId: '11111111111111111111111111111111',
    keys: [
      {
        pubkey: Keypair.generate().publicKey.toBase58(),
        isSigner: true,
        isWritable: true
      },
      {
        pubkey: testWallet.publicKey.toBase58(),
        isSigner: false,
        isWritable: true
      }
    ],
    data: Buffer.from([2, 0, 0, 0, 232, 3, 0, 0, 0, 0, 0, 0]).toString('base64')
  };

  try {
    const response = await callFunction('sponsorCustomInstruction', {
      instructions: [instruction],
      userWalletAddress: Keypair.generate().publicKey.toBase58()
    }, idToken);

    console.log(`Status: ${response.statusCode}`);
    const result = JSON.parse(response.body);

    if (result.result && result.result.success) {
      console.log('✅ SUCCESS!');
      console.log(`Signature: ${result.result.signature}`);
      console.log(`Explorer: ${result.result.explorerUrl}`);
    } else {
      console.log('⚠️  Response:', JSON.stringify(result, null, 2));
    }
  } catch (error) {
    console.log('❌ Error:', error.message);
  }
}

/**
 * Main test execution
 */
async function runTests() {
  console.log('🧪 MAINNET LIVE TRANSACTION TESTS');
  console.log('🌐 Network: Solana Mainnet-Beta');
  console.log('📡 Project: wickett-13423');
  console.log('💰 Fee Payer: 74tDwBrYudu642jnpqtfvkNpxUxiX2RVJ76jW2Ut8hUA');
  console.log('=' .repeat(80));

  try {
    // Step 1: Get custom token
    console.log('\n🔐 Step 1: Creating authentication token...');
    const customToken = await getCustomToken();
    console.log('✅ Custom token created');

    // Step 2: Sign in to get ID token
    console.log('\n🔐 Step 2: Signing in with custom token...');
    const idToken = await signInWithCustomToken(customToken);
    console.log('✅ ID token acquired');

    // Step 3: Run all tests
    console.log('\n🚀 Step 3: Running transaction tests...');

    await testSolTransfer(idToken);
    await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2s between tests

    await testSplTransfer(idToken);
    await new Promise(resolve => setTimeout(resolve, 2000));

    await testJupiterSwap(idToken);
    await new Promise(resolve => setTimeout(resolve, 2000));

    await testCustomInstruction(idToken);

    // Summary
    console.log('\n' + '=' .repeat(80));
    console.log('✅ TEST SUITE COMPLETE');
    console.log('\n📊 Next Steps:');
    console.log('   1. Review Firestore `transactions` collection for logged entries');
    console.log('   2. Check fee payer balance: solana balance 74tDwBrYudu642jnpqtfvkNpxUxiX2RVJ76jW2Ut8hUA --url mainnet-beta');
    console.log('   3. Review function logs: firebase functions:log');
    console.log('   4. If all tests passed, backend is ready for iOS integration!');

  } catch (error) {
    console.error('\n❌ Test suite failed:', error);
    process.exit(1);
  }
}

// Run tests
runTests()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
