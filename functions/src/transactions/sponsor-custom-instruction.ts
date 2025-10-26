import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { PublicKey, TransactionInstruction } from "@solana/web3.js";
import * as logger from "firebase-functions/logger";
import {
  HELIUS_RPC_URL,
  SOLANA_FEE_PAYER_PRIVATE_KEY,
  getFeePayerPublicKey,
  isWhitelistedProgram,
} from "../solana-config";
import {
  buildVersionedTransaction,
  signTransactionWithFeePayer,
  sendAndConfirmTransactionWithRetry,
  simulateTransaction,
} from "../solana/transaction-builder";
import {
  performSecurityChecks,
  updateTransactionStatus,
} from "../middleware/transaction-security";
import {
  isValidSolanaAddress,
  createErrorResponse,
  createSuccessResponse,
  validateTransactionInstructions,
} from "../solana-utils";

interface AccountMeta {
  pubkey: string;
  isSigner: boolean;
  isWritable: boolean;
}

interface CustomInstructionRequest {
  programId: string;
  accounts: AccountMeta[];
  data: number[]; // Instruction data as byte array
  memo?: string;
}

interface SponsorCustomInstructionRequest {
  instructions: CustomInstructionRequest[];
  userWalletAddress?: string; // Optional - will get from Firestore if not provided
}

interface SponsorCustomInstructionResponse {
  success: boolean;
  signature?: string;
  explorerUrl?: string;
  error?: string;
  code?: string;
}

/**
 * Sponsor a custom program instruction transaction
 * Allows interaction with whitelisted Solana programs
 * Backend pays all gas fees
 */
export const sponsorCustomInstruction = onCall<
  SponsorCustomInstructionRequest,
  Promise<SponsorCustomInstructionResponse>
>(
  {
    secrets: [HELIUS_RPC_URL, SOLANA_FEE_PAYER_PRIVATE_KEY],
    enforceAppCheck: false,
    invoker: "public",
    timeoutSeconds: 300,
  },
  async (
    request: CallableRequest<SponsorCustomInstructionRequest>
  ): Promise<SponsorCustomInstructionResponse> => {
    const { instructions: customInstructions, userWalletAddress } = request.data;

    try {
      logger.info("🚀 Starting sponsored custom instruction transaction");
      logger.info(`Number of instructions: ${customInstructions?.length || 0}`);

      // Validate request
      if (!customInstructions || customInstructions.length === 0) {
        return createErrorResponse(
          "INVALID_REQUEST",
          "At least one instruction is required"
        ) as SponsorCustomInstructionResponse;
      }

      if (customInstructions.length > 10) {
        return createErrorResponse(
          "TOO_MANY_INSTRUCTIONS",
          "Maximum 10 instructions allowed per transaction"
        ) as SponsorCustomInstructionResponse;
      }

      // Validate all program IDs are whitelisted
      for (const instruction of customInstructions) {
        if (!isValidSolanaAddress(instruction.programId)) {
          return createErrorResponse(
            "INVALID_PROGRAM_ID",
            `Invalid program ID: ${instruction.programId}`
          ) as SponsorCustomInstructionResponse;
        }

        if (!isWhitelistedProgram(instruction.programId)) {
          return createErrorResponse(
            "PROGRAM_NOT_WHITELISTED",
            `Program ${instruction.programId} is not whitelisted. Please contact support to add this program.`
          ) as SponsorCustomInstructionResponse;
        }

        logger.info(`✅ Program ${instruction.programId} is whitelisted`);
      }

      // Estimate cost for security checks
      const estimatedCostLamports = 20000 * customInstructions.length; // Rough estimate

      // Perform security checks
      const { userId, transactionId } = await performSecurityChecks(
        request,
        estimatedCostLamports
      );

      try {
        // Use wallet address from request or get from Firebase
        let userWalletFromRequest = userWalletAddress;

        if (!userWalletFromRequest) {
          const admin = await import("firebase-admin");
          const userDoc = await admin
            .firestore()
            .collection("users")
            .doc(userId)
            .get();

          const userData = userDoc.data();
          userWalletFromRequest = userData?.walletAddress;

          if (!userWalletFromRequest) {
            throw new HttpsError(
              "failed-precondition",
              "User wallet address not found"
            );
          }
        }

        logger.info(`User wallet: ${userWalletFromRequest}`);

        // Build transaction instructions
        const instructions: TransactionInstruction[] = [];

        for (const customInstruction of customInstructions) {
          // Validate all account addresses
          for (const account of customInstruction.accounts) {
            if (!isValidSolanaAddress(account.pubkey)) {
              throw new HttpsError(
                "invalid-argument",
                `Invalid account address: ${account.pubkey}`
              );
            }
          }

          // Create instruction
          const instruction = new TransactionInstruction({
            programId: new PublicKey(customInstruction.programId),
            keys: customInstruction.accounts.map((account) => ({
              pubkey: new PublicKey(account.pubkey),
              isSigner: account.isSigner,
              isWritable: account.isWritable,
            })),
            data: Buffer.from(customInstruction.data),
          });

          instructions.push(instruction);

          logger.info(
            `Added instruction for program: ${customInstruction.programId}`
          );
        }

        // Build transaction with fee payer as backend wallet
        const transaction = await buildVersionedTransaction({
          instructions,
          feePayer: getFeePayerPublicKey(),
        });

        // Validate transaction instructions for security
        const validation = validateTransactionInstructions(
          transaction,
          getFeePayerPublicKey(),
          new PublicKey(userWalletAddress)
        );

        if (!validation.valid) {
          await updateTransactionStatus(
            transactionId,
            "failed",
            undefined,
            `Validation failed: ${validation.error}`
          );
          return createErrorResponse(
            "VALIDATION_FAILED",
            `Transaction validation failed: ${validation.error}`
          ) as SponsorCustomInstructionResponse;
        }

        // Simulate transaction
        logger.info("🔍 Simulating transaction...");
        const simulation = await simulateTransaction(transaction);

        if (!simulation.success) {
          await updateTransactionStatus(
            transactionId,
            "failed",
            undefined,
            `Simulation failed: ${simulation.error}`
          );
          return createErrorResponse(
            "SIMULATION_FAILED",
            `Transaction simulation failed: ${simulation.error}`,
            { logs: simulation.logs }
          ) as SponsorCustomInstructionResponse;
        }

        logger.info("✅ Simulation successful");

        // Sign with fee payer
        signTransactionWithFeePayer(transaction);

        // NOTE: User may also need to sign if they're a signer on any accounts

        // Send and confirm
        logger.info("📤 Sending transaction to network...");
        const signature = await sendAndConfirmTransactionWithRetry(transaction, {
          maxRetries: 3,
        });

        logger.info(`✅ Transaction confirmed: ${signature}`);

        // Update transaction status
        await updateTransactionStatus(transactionId, "success", signature);

        const explorerUrl = `https://solscan.io/tx/${signature}?cluster=mainnet`;

        return createSuccessResponse(
          {
            signature,
            explorerUrl,
          },
          `Custom instruction transaction successful: ${signature}`
        ) as SponsorCustomInstructionResponse;
      } catch (error) {
        await updateTransactionStatus(
          transactionId,
          "failed",
          undefined,
          error instanceof Error ? error.message : String(error)
        );
        throw error;
      }
    } catch (error) {
      logger.error("❌ Sponsored custom instruction failed:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      return createErrorResponse(
        "TRANSACTION_FAILED",
        error instanceof Error ? error.message : "Transaction failed",
        { error }
      ) as SponsorCustomInstructionResponse;
    }
  }
);
