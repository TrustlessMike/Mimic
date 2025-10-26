import {
  Connection,
  PublicKey,
  Transaction,
  VersionedTransaction,
  TransactionMessage,
  TransactionInstruction,
  SystemProgram,
  Keypair,
  sendAndConfirmTransaction,
  VersionedTransactionResponse,
  Commitment,
} from "@solana/web3.js";
import * as logger from "firebase-functions/logger";
import { retryWithBackoff } from "../solana-utils";
import { getSolanaConnection, getFeePayerKeypair } from "../solana-config";

export interface TransactionBuilderOptions {
  feePayer?: PublicKey;
  recentBlockhash?: string;
  instructions: TransactionInstruction[];
  signers?: Keypair[];
}

/**
 * Get recent blockhash with retry
 */
export async function getRecentBlockhash(
  connection?: Connection
): Promise<{ blockhash: string; lastValidBlockHeight: number }> {
  const conn = connection || getSolanaConnection();

  return retryWithBackoff(async () => {
    const { blockhash, lastValidBlockHeight } = await conn.getLatestBlockhash("confirmed");
    logger.info(`Got recent blockhash: ${blockhash}`);
    return { blockhash, lastValidBlockHeight };
  });
}

/**
 * Build a versioned transaction with fee payer
 */
export async function buildVersionedTransaction(
  options: TransactionBuilderOptions
): Promise<VersionedTransaction> {
  const connection = getSolanaConnection();
  const feePayerKeypair = getFeePayerKeypair();

  try {
    // Get recent blockhash if not provided
    const { blockhash } = options.recentBlockhash
      ? { blockhash: options.recentBlockhash }
      : await getRecentBlockhash(connection);

    // Build transaction message
    const messageV0 = new TransactionMessage({
      payerKey: options.feePayer || feePayerKeypair.publicKey,
      recentBlockhash: blockhash,
      instructions: options.instructions,
    }).compileToV0Message();

    // Create versioned transaction
    const transaction = new VersionedTransaction(messageV0);

    logger.info("✅ Versioned transaction built successfully");
    return transaction;
  } catch (error) {
    logger.error("❌ Failed to build versioned transaction:", error);
    throw error;
  }
}

/**
 * Build a legacy transaction
 */
export async function buildLegacyTransaction(
  options: TransactionBuilderOptions
): Promise<Transaction> {
  const connection = getSolanaConnection();
  const feePayerKeypair = getFeePayerKeypair();

  try {
    const transaction = new Transaction();

    // Add instructions
    options.instructions.forEach((instruction) => {
      transaction.add(instruction);
    });

    // Get recent blockhash if not provided
    if (options.recentBlockhash) {
      transaction.recentBlockhash = options.recentBlockhash;
    } else {
      const { blockhash } = await getRecentBlockhash(connection);
      transaction.recentBlockhash = blockhash;
    }

    // Set fee payer
    transaction.feePayer = options.feePayer || feePayerKeypair.publicKey;

    logger.info("✅ Legacy transaction built successfully");
    return transaction;
  } catch (error) {
    logger.error("❌ Failed to build legacy transaction:", error);
    throw error;
  }
}

/**
 * Sign transaction with fee payer
 */
export function signTransactionWithFeePayer(
  transaction: VersionedTransaction | Transaction
): void {
  const feePayerKeypair = getFeePayerKeypair();

  try {
    if (transaction instanceof VersionedTransaction) {
      transaction.sign([feePayerKeypair]);
    } else {
      transaction.sign(feePayerKeypair);
    }
    logger.info("✅ Transaction signed with fee payer");
  } catch (error) {
    logger.error("❌ Failed to sign transaction:", error);
    throw error;
  }
}

/**
 * Send and confirm transaction
 */
export async function sendAndConfirmTransactionWithRetry(
  transaction: VersionedTransaction | Transaction,
  options: {
    maxRetries?: number;
    commitment?: Commitment;
  } = {}
): Promise<string> {
  const connection = getSolanaConnection();
  const { maxRetries = 3, commitment = "confirmed" } = options;

  return retryWithBackoff(
    async () => {
      try {
        // Send raw transaction
        const signature = await connection.sendRawTransaction(
          transaction.serialize(),
          {
            skipPreflight: false,
            preflightCommitment: commitment,
          }
        );

        logger.info(`Transaction sent: ${signature}`);

        // Confirm transaction
        const latestBlockhash = await connection.getLatestBlockhash();
        await connection.confirmTransaction(
          {
            signature,
            blockhash: latestBlockhash.blockhash,
            lastValidBlockHeight: latestBlockhash.lastValidBlockHeight,
          },
          commitment
        );

        logger.info(`✅ Transaction confirmed: ${signature}`);
        return signature;
      } catch (error) {
        logger.error("❌ Transaction failed:", error);
        throw error;
      }
    },
    maxRetries,
    2000
  );
}

/**
 * Simulate transaction before sending
 */
export async function simulateTransaction(
  transaction: VersionedTransaction | Transaction
): Promise<{ success: boolean; error?: string; logs?: string[] }> {
  const connection = getSolanaConnection();

  try {
    const simulation =
      transaction instanceof VersionedTransaction
        ? await connection.simulateTransaction(transaction)
        : await connection.simulateTransaction(transaction);

    if (simulation.value.err) {
      logger.warn("Transaction simulation failed:", simulation.value.err);
      return {
        success: false,
        error: JSON.stringify(simulation.value.err),
        logs: simulation.value.logs || [],
      };
    }

    logger.info("✅ Transaction simulation successful");
    return {
      success: true,
      logs: simulation.value.logs || [],
    };
  } catch (error) {
    logger.error("❌ Transaction simulation error:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

/**
 * Get transaction details
 */
/* export async function getTransactionDetails(
  signature: string,
  commitment: Commitment = "confirmed"
): Promise<VersionedTransactionResponse | null> {
  const connection = getSolanaConnection();

  try {
    const transaction = await connection.getTransaction(signature, {
      commitment,
      maxSupportedTransactionVersion: 0,
    });

    return transaction;
  } catch (error) {
    logger.error("Failed to get transaction details:", error);
    return null;
  }
} */

/**
 * Build and send a simple SOL transfer transaction
 */
export async function buildAndSendSolTransfer(
  fromPubkey: PublicKey,
  toPubkey: PublicKey,
  lamports: number,
  signers?: Keypair[]
): Promise<string> {
  const instruction = SystemProgram.transfer({
    fromPubkey,
    toPubkey,
    lamports,
  });

  const transaction = await buildVersionedTransaction({
    instructions: [instruction],
    signers,
  });

  // Sign with fee payer
  signTransactionWithFeePayer(transaction);

  // If additional signers, add their signatures
  if (signers && signers.length > 0) {
    transaction.sign(signers);
  }

  // Simulate first
  const simulation = await simulateTransaction(transaction);
  if (!simulation.success) {
    throw new Error(`Transaction simulation failed: ${simulation.error}`);
  }

  // Send and confirm
  const signature = await sendAndConfirmTransactionWithRetry(transaction);
  return signature;
}

/**
 * Estimate transaction fee
 */
export async function estimateTransactionFee(
  transaction: VersionedTransaction | Transaction
): Promise<number> {
  const connection = getSolanaConnection();

  try {
    const fee = await connection.getFeeForMessage(
      transaction instanceof VersionedTransaction
        ? transaction.message
        : transaction.compileMessage(),
      "confirmed"
    );

    return fee.value || 5000;
  } catch (error) {
    logger.error("Failed to estimate transaction fee:", error);
    return 5000; // Default fee estimate
  }
}
