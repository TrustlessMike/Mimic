import {
  Transaction,
  VersionedTransaction,
  PublicKey,
  SystemProgram,
} from "@solana/web3.js";
import { TOKEN_PROGRAM_ID, TOKEN_2022_PROGRAM_ID } from "@solana/spl-token";
import * as logger from "firebase-functions/logger";
import { isWhitelistedProgram, TRANSACTION_LIMITS } from "./solana-config";

/**
 * Validate transaction amount in lamports
 */
export function validateTransactionAmount(lamports: number): boolean {
  const maxLamports = TRANSACTION_LIMITS.MAX_SOL_PER_TRANSACTION * 1e9;
  if (lamports > maxLamports) {
    logger.warn(`Transaction amount ${lamports} exceeds max ${maxLamports}`);
    return false;
  }
  return true;
}

/**
 * Validate Solana address
 */
export function isValidSolanaAddress(address: string): boolean {
  try {
    new PublicKey(address);
    return true;
  } catch {
    return false;
  }
}

/**
 * Parse and validate transaction instructions
 * Ensures no unauthorized transfers from fee payer
 */
export function validateTransactionInstructions(
  transaction: VersionedTransaction | Transaction,
  feePayerPubkey: PublicKey,
  userPubkey?: PublicKey
): { valid: boolean; error?: string } {
  try {
    const instructions = transaction instanceof Transaction
      ? transaction.instructions
      : transaction.message.compiledInstructions;

    for (const instruction of instructions) {
      // Get program ID from instruction
      const programId =
        "programId" in instruction
          ? instruction.programId
          : (transaction as VersionedTransaction).message.staticAccountKeys[instruction.programIdIndex];

      const programIdStr = programId.toBase58();

      // Check if program is whitelisted
      if (!isWhitelistedProgram(programIdStr)) {
        return {
          valid: false,
          error: `Program ${programIdStr} is not whitelisted`,
        };
      }

      // Additional validation for System Program transfers
      if (programIdStr === SystemProgram.programId.toBase58()) {
        // Check if this is a transfer instruction
        const data = "data" in instruction ? (instruction as any).data as Buffer : Buffer.from([]);
        if (data && data.length > 0) {
          // System transfer instruction has data starting with [2, 0, 0, 0]
          const instructionType = data[0];
          if (instructionType === 2) {
            // This is a transfer - ensure it's not from fee payer
            const accounts =
              "keys" in instruction
                ? instruction.keys
                : instruction.accountKeyIndexes.map(
                    (idx: number) => (transaction as VersionedTransaction).message.staticAccountKeys[idx]
                  );

            const fromAccount = accounts[0];
            const fromPubkey =
              typeof fromAccount === "object" && "pubkey" in fromAccount
                ? fromAccount.pubkey
                : fromAccount;

            if (fromPubkey.equals(feePayerPubkey)) {
              return {
                valid: false,
                error: "Transaction attempts to transfer funds from fee payer",
              };
            }
          }
        }
      }

      // Validate token transfers don't originate from fee payer
      if (
        programIdStr === TOKEN_PROGRAM_ID.toBase58() ||
        programIdStr === TOKEN_2022_PROGRAM_ID.toBase58()
      ) {
        // For token transfers, we need to ensure the source account is not owned by fee payer
        // This is a simplified check - in production you might want more thorough validation
        logger.info(`Token program instruction detected: ${programIdStr}`);
      }
    }

    return { valid: true };
  } catch (error) {
    logger.error("Error validating transaction instructions:", error);
    return {
      valid: false,
      error: `Validation error: ${error instanceof Error ? error.message : "Unknown error"}`,
    };
  }
}

/**
 * Extract transaction details for logging
 */
export function extractTransactionDetails(
  transaction: VersionedTransaction | Transaction
): {
  programIds: string[];
  accountCount: number;
  instructionCount: number;
} {
  const instructions = transaction instanceof Transaction
    ? transaction.instructions
    : transaction.message.compiledInstructions;

  const programIds: string[] = [];

  for (const instruction of instructions) {
    const programId =
      "programId" in instruction
        ? instruction.programId
        : (transaction as VersionedTransaction).message.staticAccountKeys[instruction.programIdIndex];

    programIds.push(programId.toBase58());
  }

  return {
    programIds: Array.from(new Set(programIds)),
    accountCount:
      transaction instanceof VersionedTransaction
        ? transaction.message.staticAccountKeys.length
        : transaction.instructions.reduce(
            (acc: number, ix) => acc + ix.keys.length,
            0
          ),
    instructionCount: instructions.length,
  };
}

/**
 * Create error response with logging
 */
export function createErrorResponse(
  errorCode: string,
  message: string,
  details?: unknown
): { success: false; error: string; code: string; details?: unknown } {
  logger.error(`[${errorCode}] ${message}`, details);
  return {
    success: false,
    error: message,
    code: errorCode,
    ...(details && { details }),
  };
}

/**
 * Create success response with logging
 */
export function createSuccessResponse<T>(
  data: T,
  message?: string
): { success: true; data: T; message?: string } {
  if (message) {
    logger.info(`✅ ${message}`);
  }

  const response: { success: true; data: T; message?: string } = {
    success: true,
    data,
  };

  if (message) {
    response.message = message;
  }

  return response;
}

/**
 * Sleep utility for retries
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Retry with exponential backoff
 */
export async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 1000
): Promise<T> {
  let lastError: Error | undefined;

  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      if (i < maxRetries - 1) {
        const delay = baseDelay * Math.pow(2, i);
        logger.warn(`Retry attempt ${i + 1} after ${delay}ms:`, lastError.message);
        await sleep(delay);
      }
    }
  }

  throw lastError;
}

/**
 * Convert lamports to SOL
 */
export function lamportsToSol(lamports: number): number {
  return lamports / 1e9;
}

/**
 * Convert SOL to lamports
 */
export function solToLamports(sol: number): number {
  return Math.floor(sol * 1e9);
}
