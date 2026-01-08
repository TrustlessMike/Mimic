import * as logger from "firebase-functions/logger";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {
  PRIVY_APP_ID,
  PRIVY_APP_SECRET,
  PRIVY_PREDICTION_AUTH_KEY,
  getPrivyClientForPrediction,
  getPredictionKeyQuorumId,
  getWalletIdFromDid,
  getPredictionAuthKeyFormatted,
} from "../config/privy-config";
import {HELIUS_API_KEY, HELIUS_RPC_URL} from "../config/solana-config";
import {
  Connection,
  PublicKey,
  Transaction,
  TransactionInstruction,
  VersionedTransaction,
  TransactionMessage,
  ComputeBudgetProgram,
} from "@solana/web3.js";
import {
  getAssociatedTokenAddress,
  TOKEN_PROGRAM_ID,
} from "@solana/spl-token";

// Jupiter Prediction Market Program
const PREDICTION_PROGRAM_ID = new PublicKey("3ZZuTbwC6aJbvteyVxXUS7gtFYdf7AuXeitx6VyvjvUp");
const USDC_MINT = new PublicKey("EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v");

interface ExecutePredictionCopyRequest {
  pendingCopyId: string;  // ID of pending_copy_trade document
}

interface PendingCopyTrade {
  id: string;
  userId: string;
  userWalletAddress: string;
  betId: string;
  trackedWallet: string;
  marketAddress: string;
  direction: string;
  originalAmount: number;
  suggestedAmount: number;
  status: string;
  originalSignature: string;
}

/**
 * Cloud Function: Execute prediction copy trade server-side
 *
 * This function:
 * 1. Fetches the original bet transaction
 * 2. Rebuilds it for the copy user's wallet
 * 3. Signs using Privy authorization key
 * 4. Submits to Solana
 */
export const executePredictionCopyServer = onCall(
  {
    secrets: [
      PRIVY_APP_ID,
      PRIVY_APP_SECRET,
      PRIVY_PREDICTION_AUTH_KEY,
      HELIUS_API_KEY,
      HELIUS_RPC_URL,
    ],
    timeoutSeconds: 60,
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const data = request.data as ExecutePredictionCopyRequest;

    if (!data.pendingCopyId) {
      throw new HttpsError("invalid-argument", "Pending copy ID required");
    }

    logger.info(`🎯 Executing prediction copy for user ${userId}`);
    logger.info(`   Pending copy ID: ${data.pendingCopyId}`);

    const db = getFirestore();

    // Verify user has active delegation
    const activeDelegation = await db
      .collection("users")
      .doc(userId)
      .collection("prediction_delegations")
      .where("status", "==", "active")
      .limit(1)
      .get();

    if (activeDelegation.empty) {
      throw new HttpsError(
        "failed-precondition",
        "No active prediction delegation. Please enable auto-copy first."
      );
    }

    const delegation = activeDelegation.docs[0].data();

    // Check delegation hasn't expired
    const expiresAt = delegation.expiresAt?.toDate?.() || new Date(0);
    if (expiresAt < new Date()) {
      throw new HttpsError(
        "failed-precondition",
        "Delegation has expired. Please renew."
      );
    }

    // Get pending copy trade
    const pendingCopyDoc = await db
      .collection("pending_copy_trades")
      .doc(data.pendingCopyId)
      .get();

    if (!pendingCopyDoc.exists) {
      throw new HttpsError("not-found", "Pending copy trade not found");
    }

    const pendingCopy = pendingCopyDoc.data() as PendingCopyTrade;

    // Verify ownership
    if (pendingCopy.userId !== userId) {
      throw new HttpsError("permission-denied", "Not your copy trade");
    }

    // Check status
    if (pendingCopy.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `Copy trade already ${pendingCopy.status}`
      );
    }

    // Validate amount against delegation limits
    if (pendingCopy.suggestedAmount > delegation.maxCopyAmountUsd) {
      logger.warn(`Reducing copy amount from $${pendingCopy.suggestedAmount} to max $${delegation.maxCopyAmountUsd}`);
      pendingCopy.suggestedAmount = delegation.maxCopyAmountUsd;
    }

    // Get user data
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();

    if (!userData?.walletAddress || !userData?.privyUserId) {
      throw new HttpsError("failed-precondition", "Wallet not properly configured");
    }

    try {
      // Initialize Solana connection
      const rpcUrl = HELIUS_RPC_URL.value().trim();
      const connection = new Connection(rpcUrl, "confirmed");

      // Get wallet ID for Privy signing
      const appId = PRIVY_APP_ID.value().trim();
      const appSecret = PRIVY_APP_SECRET.value().trim();
      const walletId = await getWalletIdFromDid(
        userData.privyUserId,
        appId,
        appSecret,
        userData.walletAddress
      );

      logger.info(`✅ Wallet ID: ${walletId}`);

      // Fetch original transaction to copy instruction format
      const originalTx = await fetchOriginalTransaction(
        connection,
        pendingCopy.originalSignature || pendingCopy.betId
      );

      if (!originalTx) {
        throw new Error("Could not fetch original transaction");
      }

      // Build copy transaction
      const copyTx = await buildCopyTransaction(
        connection,
        originalTx,
        new PublicKey(userData.walletAddress),
        pendingCopy.suggestedAmount,
        pendingCopy.direction
      );

      logger.info(`📝 Built copy transaction`);

      // Sign using Privy
      const privy = getPrivyClientForPrediction();
      const authKey = getPredictionAuthKeyFormatted();

      // Serialize transaction for signing
      const serializedTx = Buffer.from(copyTx.serialize()).toString("base64");

      logger.info(`🔐 Signing with Privy prediction auth key...`);

      // Sign transaction using Privy authorization key
      const signResult = await privy.wallets().solana().signTransaction(
        walletId,
        {
          transaction: serializedTx,
          authorization_context: {
            authorization_private_keys: [authKey],
          },
        }
      );

      logger.info(`✅ Transaction signed, broadcasting to Solana...`);

      // Broadcast the signed transaction
      const signedTxBuffer = Buffer.from(signResult.signed_transaction, "base64");
      const signature = await connection.sendRawTransaction(signedTxBuffer, {
        skipPreflight: false,
        preflightCommitment: "confirmed",
      });

      // Wait for confirmation
      await connection.confirmTransaction(signature, "confirmed");

      logger.info(`✅ Transaction confirmed: ${signature}`);

      // Update pending copy status
      await pendingCopyDoc.ref.update({
        status: "executed",
        executedAt: FieldValue.serverTimestamp(),
        executedSignature: signature,
        executedAmount: pendingCopy.suggestedAmount,
        executedServerSide: true,
      });

      // Update delegation stats
      await activeDelegation.docs[0].ref.update({
        totalCopiesExecuted: FieldValue.increment(1),
        totalVolumeUsd: FieldValue.increment(pendingCopy.suggestedAmount),
        lastCopyAt: FieldValue.serverTimestamp(),
      });

      // Record in copy history
      await db.collection("users").doc(userId).collection("copy_history").add({
        pendingCopyId: data.pendingCopyId,
        trackedWallet: pendingCopy.trackedWallet,
        marketAddress: pendingCopy.marketAddress,
        direction: pendingCopy.direction,
        originalAmount: pendingCopy.originalAmount,
        copyAmount: pendingCopy.suggestedAmount,
        signature: signature,
        executedAt: FieldValue.serverTimestamp(),
        serverSide: true,
      });

      return {
        success: true,
        signature: signature,
        amount: pendingCopy.suggestedAmount,
        direction: pendingCopy.direction,
        message: `Successfully copied ${pendingCopy.direction} bet for $${pendingCopy.suggestedAmount}`,
      };

    } catch (error: any) {
      logger.error("❌ Failed to execute prediction copy:", error);

      // Update pending copy with error
      await pendingCopyDoc.ref.update({
        status: "failed",
        failedAt: FieldValue.serverTimestamp(),
        failureReason: error.message || "Unknown error",
      });

      throw new HttpsError(
        "internal",
        `Failed to execute copy: ${error.message || error}`
      );
    }
  }
);

/**
 * Fetch and parse original transaction
 */
async function fetchOriginalTransaction(
  connection: Connection,
  signature: string
): Promise<any> {
  logger.info(`📥 Fetching original transaction: ${signature}`);

  const tx = await connection.getTransaction(signature, {
    maxSupportedTransactionVersion: 0,
  });

  if (!tx) {
    throw new Error(`Transaction not found: ${signature}`);
  }

  return tx;
}

/**
 * Build copy transaction based on original
 */
async function buildCopyTransaction(
  connection: Connection,
  originalTx: any,
  copyUserWallet: PublicKey,
  copyAmountUsd: number,
  direction: string
): Promise<VersionedTransaction> {
  logger.info(`🔨 Building copy transaction for ${copyUserWallet.toBase58()}`);
  logger.info(`   Amount: $${copyAmountUsd}`);
  logger.info(`   Direction: ${direction}`);

  // Get account keys from original transaction
  const accountKeys = originalTx.transaction.message.staticAccountKeys ||
                      originalTx.transaction.message.accountKeys;

  // Find the prediction program instruction
  let predictionIx: any = null;
  let predictionIxAccounts: PublicKey[] = [];

  for (const ix of originalTx.transaction.message.instructions) {
    const programId = accountKeys[ix.programIdIndex];
    if (programId.equals(PREDICTION_PROGRAM_ID)) {
      predictionIx = ix;
      predictionIxAccounts = ix.accounts.map((idx: number) => accountKeys[idx]);
      break;
    }
  }

  if (!predictionIx) {
    throw new Error("Could not find prediction instruction in original transaction");
  }

  logger.info(`   Found prediction instruction with ${predictionIxAccounts.length} accounts`);

  // Get copy user's USDC ATA
  const copyUserUsdcAta = await getAssociatedTokenAddress(
    USDC_MINT,
    copyUserWallet
  );

  // Build new account list
  // Based on analysis:
  // [0] User wallet (signer) - REPLACE
  // [1] Market account - keep
  // [2-4] Pool/vault accounts - keep
  // [5] User's USDC ATA - REPLACE
  // [6+] Programs and other accounts - keep

  const newAccounts = [...predictionIxAccounts];
  newAccounts[0] = copyUserWallet;        // Replace user wallet
  newAccounts[5] = copyUserUsdcAta;       // Replace user's USDC ATA

  // TODO: Properly encode amount in instruction data
  // For now, use original instruction data (same bet structure)
  const instructionData = Buffer.from(
    originalTx.transaction.message.instructions[
      originalTx.transaction.message.instructions.findIndex(
        (ix: any) => accountKeys[ix.programIdIndex].equals(PREDICTION_PROGRAM_ID)
      )
    ].data,
    "base64"
  );

  // Create new instruction
  const newInstruction = new TransactionInstruction({
    programId: PREDICTION_PROGRAM_ID,
    keys: newAccounts.map((pubkey, index) => ({
      pubkey,
      isSigner: index === 0,  // Only first account (user) is signer
      isWritable: index < 6,  // First 6 accounts are typically writable
    })),
    data: instructionData,
  });

  // Add compute budget for priority
  const computeBudgetIx = ComputeBudgetProgram.setComputeUnitPrice({
    microLamports: 50000,  // 0.00005 SOL per CU
  });

  const computeLimitIx = ComputeBudgetProgram.setComputeUnitLimit({
    units: 300000,
  });

  // Get recent blockhash
  const {blockhash} = await connection.getLatestBlockhash("confirmed");

  // Build versioned transaction
  const message = new TransactionMessage({
    payerKey: copyUserWallet,
    recentBlockhash: blockhash,
    instructions: [computeBudgetIx, computeLimitIx, newInstruction],
  }).compileToV0Message();

  return new VersionedTransaction(message);
}

/**
 * Auto-execute copy trades for users with delegation
 * Called by the tracker when a bet is detected
 */
export async function autoExecutePredictionCopy(
  pendingCopyId: string,
  userId: string
): Promise<{success: boolean; signature?: string; error?: string}> {
  logger.info(`🤖 Auto-executing prediction copy: ${pendingCopyId}`);

  const db = getFirestore();

  // Check if user has active delegation
  const userDoc = await db.collection("users").doc(userId).get();
  const userData = userDoc.data();

  if (!userData?.predictionDelegationActive) {
    return {
      success: false,
      error: "User does not have active delegation",
    };
  }

  try {
    // This will be called internally, simulating an authenticated call
    // In practice, we'd call the Cloud Function directly

    // For now, return that manual execution is needed
    // The actual auto-execution will be triggered differently
    return {
      success: false,
      error: "Auto-execution must be triggered via Cloud Function",
    };

  } catch (error: any) {
    logger.error("Auto-execute error:", error);
    return {
      success: false,
      error: error.message || "Unknown error",
    };
  }
}
