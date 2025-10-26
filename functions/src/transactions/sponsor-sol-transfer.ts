import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { PublicKey, SystemProgram } from "@solana/web3.js";
import * as logger from "firebase-functions/logger";
import {
  HELIUS_RPC_URL,
  SOLANA_FEE_PAYER_PRIVATE_KEY,
  getFeePayerPublicKey,
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
import { isValidSolanaAddress, createErrorResponse, createSuccessResponse } from "../solana-utils";

interface SponsorSolTransferRequest {
  destinationAddress: string;
  amountLamports: number;
  userWalletAddress?: string; // Optional - will get from Firestore if not provided
  memo?: string;
}

interface SponsorSolTransferResponse {
  success: boolean;
  signature?: string;
  explorerUrl?: string;
  error?: string;
  code?: string;
}

/**
 * Sponsor a SOL transfer transaction
 * User doesn't pay gas - backend fee payer sponsors the transaction
 */
export const sponsorSolTransfer = onCall<
  SponsorSolTransferRequest,
  Promise<SponsorSolTransferResponse>
>(
  {
    secrets: [HELIUS_RPC_URL, SOLANA_FEE_PAYER_PRIVATE_KEY],
    enforceAppCheck: false,
    invoker: "public",
  },
  async (
    request: CallableRequest<SponsorSolTransferRequest>
  ): Promise<SponsorSolTransferResponse> => {
    const { destinationAddress, amountLamports, userWalletAddress, memo } = request.data;

    try {
      logger.info("🚀 Starting sponsored SOL transfer");
      logger.info(`Destination: ${destinationAddress}`);
      logger.info(`Amount: ${amountLamports} lamports (${amountLamports / 1e9} SOL)`);

      // Validate destination address
      if (!isValidSolanaAddress(destinationAddress)) {
        return createErrorResponse(
          "INVALID_ADDRESS",
          "Invalid destination address"
        ) as SponsorSolTransferResponse;
      }

      // Perform security checks (auth, rate limiting, amount validation, logging)
      const { userId, transactionId } = await performSecurityChecks(
        request,
        amountLamports
      );

      try {
        // Use wallet address from request (for testing) or get from Firebase
        let userWalletFromRequest = userWalletAddress;

        // If not provided in request, get from Firebase (from Privy)
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
              "User wallet address not found. Please ensure your wallet is set up."
            );
          }
        }

        logger.info(`User wallet: ${userWalletFromRequest}`);

        // Validate user has sufficient balance
        const { getSolanaConnection } = await import("../solana-config");
        const connection = getSolanaConnection();
        const userBalance = await connection.getBalance(new PublicKey(userWalletFromRequest));

        if (userBalance < amountLamports) {
          await updateTransactionStatus(
            transactionId,
            "failed",
            undefined,
            "Insufficient balance"
          );
          return createErrorResponse(
            "INSUFFICIENT_BALANCE",
            `Insufficient balance. Required: ${amountLamports / 1e9} SOL, Available: ${userBalance / 1e9} SOL`
          ) as SponsorSolTransferResponse;
        }

        // Build transfer instruction from user to destination
        const transferInstruction = SystemProgram.transfer({
          fromPubkey: new PublicKey(userWalletFromRequest),
          toPubkey: new PublicKey(destinationAddress),
          lamports: amountLamports,
        });

        // Build transaction with fee payer as backend wallet
        const transaction = await buildVersionedTransaction({
          instructions: [transferInstruction],
          feePayer: getFeePayerPublicKey(), // Backend pays the fee
        });

        // Simulate transaction first
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
          ) as SponsorSolTransferResponse;
        }

        logger.info("✅ Simulation successful");

        // Sign transaction with fee payer (backend wallet pays gas)
        signTransactionWithFeePayer(transaction);

        // NOTE: User would also need to sign this transaction in a real implementation
        // For now, this assumes we're doing a gasless transaction where the user
        // has pre-authorized the transfer through a different mechanism

        // Send and confirm transaction
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
          `SOL transfer successful: ${signature}`
        ) as SponsorSolTransferResponse;
      } catch (error) {
        // Update transaction status to failed
        await updateTransactionStatus(
          transactionId,
          "failed",
          undefined,
          error instanceof Error ? error.message : String(error)
        );

        throw error;
      }
    } catch (error) {
      logger.error("❌ Sponsored SOL transfer failed:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      return createErrorResponse(
        "TRANSACTION_FAILED",
        error instanceof Error ? error.message : "Transaction failed",
        { error }
      ) as SponsorSolTransferResponse;
    }
  }
);
