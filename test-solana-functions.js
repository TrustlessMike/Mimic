#!/usr/bin/env node

/**
 * Comprehensive Test Suite for Solana Transaction Backend
 * Tests all deployed Firebase Functions on Solana mainnet
 */

const admin = require('firebase-admin');
const { Keypair } = require('@solana/web3.js');
const axios = require('axios');

// Initialize Firebase Admin
const serviceAccount = require('./wickett-13423-firebase-adminsdk.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const functions = admin.functions();

// Test configuration
const TEST_CONFIG = {
  projectId: 'wickett-13423',
  region: 'us-central1',
  feePayerAddress: '74tDwBrYudu642jnpqtfvkNpxUxiX2RVJ76jW2Ut8hUA',
};

// Test results tracker
const testResults = {
  passed: 0,
  failed: 0,
  skipped: 0,
  tests: []
};

/**
 * Get Firebase Auth user for testing
 */
async function getTestUser() {
  try {
    const users = await admin.auth().listUsers(1);
    if (users.users.length === 0) {
      throw new Error('No Firebase users found for testing');
    }
    return users.users[0];
  } catch (error) {
    console.error('❌ Error getting test user:', error);
    throw error;
  }
}

/**
 * Get user's Solana wallet from Firestore
 */
async function getUserWallet(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throw new Error('User document not found');
  }
  const data = userDoc.data();
  return data.walletAddress;
}

/**
 * Call Firebase Function with proper authentication
 */
async function callFunction(functionName, data, userId) {
  try {
    // Create custom token for the user
    const customToken = await admin.auth().createCustomToken(userId);

    // Get function URL
    const functionUrl = `https://us-central1-wickett-13423.cloudfunctions.net/${functionName}`;

    console.log(`📞 Calling ${functionName}...`);

    // Call function via HTTP (simulating client call)
    const response = await axios.post(functionUrl, {
      data: data
    }, {
      headers: {
        'Authorization': `Bearer ${customToken}`,
        'Content-Type': 'application/json'
      },
      timeout: 60000 // 60 second timeout
    });

    return response.data;
  } catch (error) {
    if (error.response) {
      return {
        error: true,
        status: error.response.status,
        message: error.response.data?.error?.message || error.response.data,
        data: error.response.data
      };
    }
    throw error;
  }
}

/**
 * Check Solana balance via RPC
 */
async function checkSolanaBalance(address) {
  try {
    const response = await axios.post('https://api.mainnet-beta.solana.com', {
      jsonrpc: '2.0',
      id: 1,
      method: 'getBalance',
      params: [address]
    });
    return response.data.result.value / 1e9; // Convert lamports to SOL
  } catch (error) {
    console.error('Error checking balance:', error.message);
    return null;
  }
}

/**
 * Test 1: SOL Transfer
 */
async function testSolTransfer(userId, userWallet) {
  console.log('\n🧪 TEST 1: SOL Transfer (sponsorSolTransfer)');
  console.log('=' .repeat(80));

  try {
    // Generate temporary recipient wallet
    const recipient = Keypair.generate();
    const recipientAddress = recipient.publicKey.toBase58();

    console.log(`📤 Sending 0.0001 SOL to ${recipientAddress}`);
    console.log(`👤 From user wallet: ${userWallet}`);

    // Check user wallet balance first
    const userBalance = await checkSolanaBalance(userWallet);
    console.log(`💰 User wallet balance: ${userBalance} SOL`);

    if (userBalance < 0.0001) {
      console.log('⚠️  User wallet has insufficient balance for transfer');
      console.log('   Test will likely fail with "Insufficient balance" error');
      testResults.skipped++;
      testResults.tests.push({
        name: 'SOL Transfer',
        status: 'SKIPPED',
        reason: 'Insufficient user wallet balance'
      });
      return;
    }

    // Call the function
    const startTime = Date.now();
    const result = await callFunction('sponsorSolTransfer', {
      destinationAddress: recipientAddress,
      amountLamports: 100000 // 0.0001 SOL
    }, userId);
    const duration = Date.now() - startTime;

    console.log(`⏱️  Response time: ${duration}ms`);

    if (result.error) {
      console.log('❌ Function returned error:', result.message);
      testResults.failed++;
      testResults.tests.push({
        name: 'SOL Transfer',
        status: 'FAILED',
        error: result.message,
        duration
      });
      return;
    }

    // Check result
    if (result.result && result.result.success) {
      console.log('✅ Transaction successful!');
      console.log(`📝 Signature: ${result.result.data.signature}`);
      console.log(`🔗 Explorer: ${result.result.data.explorerUrl}`);

      // Verify on-chain
      await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
      const recipientBalance = await checkSolanaBalance(recipientAddress);
      console.log(`💰 Recipient balance: ${recipientBalance} SOL`);

      testResults.passed++;
      testResults.tests.push({
        name: 'SOL Transfer',
        status: 'PASSED',
        signature: result.result.data.signature,
        explorerUrl: result.result.data.explorerUrl,
        duration,
        recipientBalance
      });
    } else {
      console.log('❌ Unexpected response format:', result);
      testResults.failed++;
      testResults.tests.push({
        name: 'SOL Transfer',
        status: 'FAILED',
        error: 'Unexpected response format',
        duration
      });
    }

  } catch (error) {
    console.log('❌ Test failed with exception:', error.message);
    testResults.failed++;
    testResults.tests.push({
      name: 'SOL Transfer',
      status: 'FAILED',
      error: error.message
    });
  }
}

/**
 * Test 2: Authentication & Security
 */
async function testAuthentication() {
  console.log('\n🧪 TEST 2: Authentication & Security');
  console.log('=' .repeat(80));

  try {
    const recipient = Keypair.generate().publicKey.toBase58();

    // Test without authentication
    console.log('🔒 Testing unauthenticated request...');
    const functionUrl = `https://us-central1-wickett-13423.cloudfunctions.net/sponsorSolTransfer`;

    try {
      const response = await axios.post(functionUrl, {
        data: {
          destinationAddress: recipient,
          amountLamports: 1000
        }
      }, {
        headers: {
          'Content-Type': 'application/json'
        },
        timeout: 10000
      });

      console.log('❌ Unauthenticated request should have been rejected!');
      testResults.failed++;
      testResults.tests.push({
        name: 'Authentication Check',
        status: 'FAILED',
        error: 'Unauthenticated request was not rejected'
      });
    } catch (error) {
      if (error.response && (error.response.status === 401 || error.response.status === 403)) {
        console.log('✅ Unauthenticated request properly rejected');
        testResults.passed++;
        testResults.tests.push({
          name: 'Authentication Check',
          status: 'PASSED'
        });
      } else {
        console.log('⚠️  Unexpected error:', error.message);
        testResults.failed++;
        testResults.tests.push({
          name: 'Authentication Check',
          status: 'FAILED',
          error: error.message
        });
      }
    }

  } catch (error) {
    console.log('❌ Authentication test failed:', error.message);
    testResults.failed++;
    testResults.tests.push({
      name: 'Authentication Check',
      status: 'FAILED',
      error: error.message
    });
  }
}

/**
 * Test 6: Firestore Logging
 */
async function testFirestoreLogging(userId) {
  console.log('\n🧪 TEST 6: Firestore Transaction Logging');
  console.log('=' .repeat(80));

  try {
    // Query recent transactions
    const snapshot = await db.collection('transactions')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(5)
      .get();

    console.log(`📊 Found ${snapshot.size} recent transactions`);

    if (snapshot.size > 0) {
      console.log('✅ Firestore logging is working');

      snapshot.forEach((doc, index) => {
        const data = doc.data();
        console.log(`\n   Transaction ${index + 1}:`);
        console.log(`   - ID: ${doc.id}`);
        console.log(`   - Type: ${data.type}`);
        console.log(`   - Status: ${data.status}`);
        console.log(`   - Amount: ${data.amount} lamports`);
        if (data.signature) {
          console.log(`   - Signature: ${data.signature}`);
        }
      });

      testResults.passed++;
      testResults.tests.push({
        name: 'Firestore Logging',
        status: 'PASSED',
        transactionsFound: snapshot.size
      });
    } else {
      console.log('⚠️  No transactions found in Firestore');
      testResults.tests.push({
        name: 'Firestore Logging',
        status: 'SKIPPED',
        reason: 'No transactions to verify'
      });
    }

  } catch (error) {
    console.log('❌ Firestore logging test failed:', error.message);
    testResults.failed++;
    testResults.tests.push({
      name: 'Firestore Logging',
      status: 'FAILED',
      error: error.message
    });
  }
}

/**
 * Print test summary
 */
function printSummary() {
  console.log('\n' + '='.repeat(80));
  console.log('📊 TEST SUMMARY');
  console.log('='.repeat(80));
  console.log(`✅ Passed: ${testResults.passed}`);
  console.log(`❌ Failed: ${testResults.failed}`);
  console.log(`⏭️  Skipped: ${testResults.skipped}`);
  console.log(`📝 Total Tests: ${testResults.tests.length}`);

  const successRate = testResults.tests.length > 0
    ? ((testResults.passed / testResults.tests.length) * 100).toFixed(1)
    : 0;
  console.log(`📈 Success Rate: ${successRate}%`);

  console.log('\n' + '='.repeat(80));
  console.log('📋 DETAILED RESULTS');
  console.log('='.repeat(80));

  testResults.tests.forEach((test, index) => {
    console.log(`\n${index + 1}. ${test.name}: ${test.status}`);
    if (test.error) console.log(`   Error: ${test.error}`);
    if (test.signature) console.log(`   Signature: ${test.signature}`);
    if (test.explorerUrl) console.log(`   Explorer: ${test.explorerUrl}`);
    if (test.duration) console.log(`   Duration: ${test.duration}ms`);
  });

  console.log('\n' + '='.repeat(80));
}

/**
 * Main test runner
 */
async function runTests() {
  console.log('🚀 Starting Solana Transaction Backend Tests');
  console.log('🌐 Network: Solana Mainnet-Beta');
  console.log('💼 Fee Payer: ' + TEST_CONFIG.feePayerAddress);
  console.log('='.repeat(80));

  try {
    // Get test user
    const testUser = await getTestUser();
    console.log(`\n👤 Test User: ${testUser.uid}`);
    console.log(`📧 Email: ${testUser.email || 'N/A'}`);

    // Get user's wallet
    const userWallet = await getUserWallet(testUser.uid);
    console.log(`💼 User Wallet: ${userWallet}`);

    // Check fee payer balance
    const feePayerBalance = await checkSolanaBalance(TEST_CONFIG.feePayerAddress);
    console.log(`💰 Fee Payer Balance: ${feePayerBalance} SOL`);

    // Run tests
    await testAuthentication();
    await testSolTransfer(testUser.uid, userWallet);
    await testFirestoreLogging(testUser.uid);

    // Print summary
    printSummary();

    // Exit with appropriate code
    process.exit(testResults.failed > 0 ? 1 : 0);

  } catch (error) {
    console.error('\n❌ Fatal error running tests:', error);
    process.exit(1);
  }
}

// Run tests
runTests().catch(console.error);
