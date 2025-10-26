#!/usr/bin/env node

/**
 * Mainnet Live Transaction Test with CLI Authentication
 * Tests all 4 Solana functions with real authenticated transactions
 */

const { Keypair, PublicKey } = require('@solana/web3.js');
const https = require('https');

// Configuration
const PRIVY_USER_ID = 'did:privy:cmh87nmms00rblb0dnjv8yqhj';
const FIREBASE_API_KEY = 'AIzaSyA5SRdTNzfTj0mOjHS5bMQNb3UwJjW0MKo';
const PROJECT_ID = 'wickett-13423';
const REGION = 'us-central1';

// Test wallet for receiving transfers
const TEST_WALLET = Keypair.generate();
const USER_WALLET = Keypair.generate(); // Simulated user wallet

console.log(`\n${'='.repeat(80)}`);
console.log('🧪 MAINNET LIVE TRANSACTION TESTS');
console.log(`${'='.repeat(80)}`);
console.log(`🌐 Network: Solana Mainnet-Beta`);
console.log(`📡 Project: ${PROJECT_ID}`);
console.log(`💰 Fee Payer: 74tDwBrYudu642jnpqtfvkNpxUxiX2RVJ76jW2Ut8hUA`);
console.log(`👤 Test User: ${PRIVY_USER_ID}`);
console.log(`📥 Test Recipient: ${TEST_WALLET.publicKey.toBase58()}`);
console.log(`👛 Simulated User Wallet: ${USER_WALLET.publicKey.toBase58()}`);
console.log(`${'='.repeat(80)}\n`);

/**
 * Make HTTPS POST request
 */
function httpsPost(hostname, path, data, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(data);

    const options = {
      hostname,
      port: 443,
      path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        ...headers
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
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
 * Step 1: Get custom token from Firebase
 */
async function getCustomToken() {
  console.log('🔐 Step 1: Creating custom token...');

  const response = await httpsPost(
    `${REGION}-${PROJECT_ID}.cloudfunctions.net`,
    '/createFirebaseCustomToken',
    {
      data: {
        privyUserId: PRIVY_USER_ID,
        authMethod: 'test-cli',
        timestamp: Date.now()
      }
    }
  );

  if (response.statusCode !== 200) {
    throw new Error(`Failed to get custom token: ${response.body}`);
  }

  const result = JSON.parse(response.body);
  if (!result.result || !result.result.customToken) {
    throw new Error(`Invalid response: ${response.body}`);
  }

  console.log(`✅ Custom token created for: ${result.result.firebaseUid}`);
  return result.result.customToken;
}

/**
 * Step 2: Exchange custom token for ID token
 */
async function getIdToken(customToken) {
  console.log('🔐 Step 2: Exchanging for ID token...');

  const response = await httpsPost(
    'identitytoolkit.googleapis.com',
    `/v1/accounts:signInWithCustomToken?key=${FIREBASE_API_KEY}`,
    {
      token: customToken,
      returnSecureToken: true
    }
  );

  if (response.statusCode !== 200) {
    throw new Error(`Failed to get ID token: ${response.body}`);
  }

  const result = JSON.parse(response.body);
  if (!result.idToken) {
    throw new Error(`No ID token in response: ${response.body}`);
  }

  console.log('✅ ID token acquired\n');
  return result.idToken;
}

/**
 * Call a Cloud Function with authentication
 */
async function callFunction(functionName, data, idToken) {
  const response = await httpsPost(
    `${REGION}-${PROJECT_ID}.cloudfunctions.net`,
    `/${functionName}`,
    { data },
    { 'Authorization': `Bearer ${idToken}` }
  );

  return {
    statusCode: response.statusCode,
    body: response.body,
    result: response.statusCode === 200 ? JSON.parse(response.body) : null
  };
}

/**
 * Test 1: SOL Transfer
 */
async function testSolTransfer(idToken) {
  console.log(`\n${'─'.repeat(80)}`);
  console.log('📍 TEST 1: Sponsored SOL Transfer');
  console.log(`${'─'.repeat(80)}`);
  console.log(`From: ${USER_WALLET.publicKey.toBase58()}`);
  console.log(`To: ${TEST_WALLET.publicKey.toBase58()}`);
  console.log(`Amount: 1,000 lamports (0.000001 SOL)`);
  console.log('');

  try {
    const response = await callFunction('sponsorSolTransfer', {
      userWalletAddress: USER_WALLET.publicKey.toBase58(),
      destinationAddress: TEST_WALLET.publicKey.toBase58(),
      amountLamports: 1000
    }, idToken);

    console.log(`Status: ${response.statusCode}`);

    if (response.result && response.result.result) {
      const data = response.result.result;
      if (data.success) {
        console.log('✅ SUCCESS!');
        console.log(`Signature: ${data.signature}`);
        console.log(`Explorer: ${data.explorerUrl}`);
        return { success: true, signature: data.signature };
      }
    }

    console.log('⚠️  Response:', response.body.substring(0, 500));
    return { success: false, error: response.body };

  } catch (error) {
    console.log('❌ Error:', error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Test 2: SPL Token Transfer
 */
async function testSplTransfer(idToken) {
  console.log(`\n${'─'.repeat(80)}`);
  console.log('📍 TEST 2: Sponsored SPL Token Transfer (USDC)');
  console.log(`${'─'.repeat(80)}`);
  console.log(`From: ${USER_WALLET.publicKey.toBase58()}`);
  console.log(`To: ${TEST_WALLET.publicKey.toBase58()}`);
  console.log(`Token: USDC (EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v)`);
  console.log(`Amount: 100 (0.0001 USDC)`);
  console.log('');

  try {
    const response = await callFunction('sponsorSplTransfer', {
      userWalletAddress: USER_WALLET.publicKey.toBase58(),
      destinationAddress: TEST_WALLET.publicKey.toBase58(),
      tokenMintAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', // USDC
      amount: 100
    }, idToken);

    console.log(`Status: ${response.statusCode}`);

    if (response.result && response.result.result) {
      const data = response.result.result;
      if (data.success) {
        console.log('✅ SUCCESS!');
        console.log(`Signature: ${data.signature}`);
        console.log(`Explorer: ${data.explorerUrl}`);
        return { success: true, signature: data.signature };
      }
    }

    console.log('⚠️  Response:', response.body.substring(0, 500));
    return { success: false, error: response.body };

  } catch (error) {
    console.log('❌ Error:', error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Test 3: Jupiter Swap
 */
async function testJupiterSwap(idToken) {
  console.log(`\n${'─'.repeat(80)}`);
  console.log('📍 TEST 3: Sponsored Jupiter Swap (SOL → USDC)');
  console.log(`${'─'.repeat(80)}`);
  console.log(`User Wallet: ${USER_WALLET.publicKey.toBase58()}`);
  console.log(`Input: SOL (So11111111111111111111111111111111111111112)`);
  console.log(`Output: USDC (EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v)`);
  console.log(`Amount: 1,000,000 lamports (0.001 SOL)`);
  console.log(`Slippage: 0.5%`);
  console.log('');

  try {
    const response = await callFunction('sponsorJupiterSwap', {
      userWalletAddress: USER_WALLET.publicKey.toBase58(),
      inputMint: 'So11111111111111111111111111111111111111112', // Wrapped SOL
      outputMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', // USDC
      amount: 1000000, // 0.001 SOL
      slippageBps: 50 // 0.5%
    }, idToken);

    console.log(`Status: ${response.statusCode}`);

    if (response.result && response.result.result) {
      const data = response.result.result;
      if (data.success) {
        console.log('✅ SUCCESS!');
        console.log(`Signature: ${data.signature}`);
        console.log(`Explorer: ${data.explorerUrl}`);
        return { success: true, signature: data.signature };
      }
    }

    console.log('⚠️  Response:', response.body.substring(0, 500));
    return { success: false, error: response.body };

  } catch (error) {
    console.log('❌ Error:', error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Test 4: Custom Instruction
 */
async function testCustomInstruction(idToken) {
  console.log(`\n${'─'.repeat(80)}`);
  console.log('📍 TEST 4: Sponsored Custom Instruction (System Program)');
  console.log(`${'─'.repeat(80)}`);
  console.log(`User Wallet: ${USER_WALLET.publicKey.toBase58()}`);
  console.log(`Program: System Program (11111111111111111111111111111111)`);
  console.log(`Operation: Transfer 1,000 lamports`);
  console.log('');

  // Build a simple system transfer instruction
  const instruction = {
    programId: '11111111111111111111111111111111',
    keys: [
      {
        pubkey: USER_WALLET.publicKey.toBase58(),
        isSigner: true,
        isWritable: true
      },
      {
        pubkey: TEST_WALLET.publicKey.toBase58(),
        isSigner: false,
        isWritable: true
      }
    ],
    // Transfer instruction: [2, 0, 0, 0] (instruction discriminator) + amount in little-endian
    data: Buffer.from([2, 0, 0, 0, 232, 3, 0, 0, 0, 0, 0, 0]).toString('base64')
  };

  try {
    const response = await callFunction('sponsorCustomInstruction', {
      userWalletAddress: USER_WALLET.publicKey.toBase58(),
      instructions: [instruction]
    }, idToken);

    console.log(`Status: ${response.statusCode}`);

    if (response.result && response.result.result) {
      const data = response.result.result;
      if (data.success) {
        console.log('✅ SUCCESS!');
        console.log(`Signature: ${data.signature}`);
        console.log(`Explorer: ${data.explorerUrl}`);
        return { success: true, signature: data.signature };
      }
    }

    console.log('⚠️  Response:', response.body.substring(0, 500));
    return { success: false, error: response.body };

  } catch (error) {
    console.log('❌ Error:', error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Main test runner
 */
async function runTests() {
  const results = {
    solTransfer: null,
    splTransfer: null,
    jupiterSwap: null,
    customInstruction: null
  };

  try {
    // Authenticate
    const customToken = await getCustomToken();
    const idToken = await getIdToken(customToken);

    console.log('🚀 Step 3: Running transaction tests...');

    // Test 1: SOL Transfer
    results.solTransfer = await testSolTransfer(idToken);
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Test 2: SPL Transfer
    results.splTransfer = await testSplTransfer(idToken);
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Test 3: Jupiter Swap
    results.jupiterSwap = await testJupiterSwap(idToken);
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Test 4: Custom Instruction
    results.customInstruction = await testCustomInstruction(idToken);

    // Summary
    console.log(`\n${'='.repeat(80)}`);
    console.log('📊 TEST SUMMARY');
    console.log(`${'='.repeat(80)}`);

    const tests = [
      ['SOL Transfer', results.solTransfer],
      ['SPL Transfer', results.splTransfer],
      ['Jupiter Swap', results.jupiterSwap],
      ['Custom Instruction', results.customInstruction]
    ];

    tests.forEach(([name, result]) => {
      if (result.success) {
        console.log(`✅ ${name}: SUCCESS`);
        console.log(`   Signature: ${result.signature}`);
      } else {
        console.log(`❌ ${name}: FAILED`);
        console.log(`   Error: ${result.error.substring(0, 100)}...`);
      }
    });

    console.log(`\n${'='.repeat(80)}`);
    console.log('📋 NEXT STEPS:');
    console.log(`${'='.repeat(80)}`);
    console.log('1. Check Firestore transactions collection:');
    console.log('   https://console.firebase.google.com/project/wickett-13423/firestore/data/transactions');
    console.log('');
    console.log('2. Check fee payer balance:');
    console.log('   solana balance 74tDwBrYudu642jnpqtfvkNpxUxiX2RVJ76jW2Ut8hUA --url mainnet-beta');
    console.log('');
    console.log('3. Review function logs:');
    console.log('   firebase functions:log --only sponsorSolTransfer');
    console.log('');
    console.log('4. If all tests passed, backend is ready for iOS integration!');
    console.log(`${'='.repeat(80)}\n`);

    return results;

  } catch (error) {
    console.error('\n❌ Fatal error:', error);
    throw error;
  }
}

// Run the tests
runTests()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Test suite failed:', error);
    process.exit(1);
  });
