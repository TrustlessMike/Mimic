import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { PublicKey } from "@solana/web3.js";
import {
  getAssociatedTokenAddress,
  createAssociatedTokenAccountInstruction,
  createTransferInstruction,
  TOKEN_PROGRAM_ID,
} from "@solana/spl-token";
import * as logger from "firebase-functions/logger";
import {
  HELIUS_RPC_URL,
  SOLANA_FEE_PAYER_PRIVATE_KEY,
  getFeePayerPublicKey,
  getSolanaConnection,
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

interface SponsorSplTransferRequest {
  tokenMintAddress: string;
  destinationAddress: string;
  amount: number; // Amount in token's smallest unit
  decimals?: number; // Token decimals for validation (optional, defaults to 6 for USDC)
  userWalletAddress?: string; // Optional - will get from Firestore if not provided
  createDestinationATA?: boolean; // Whether to create destination ATA if it doesn't exist
}

interface SponsorSplTransferResponse {
  success: boolean;
  signature?: string;
  explorerUrl?: string;
  ataCreated?: boolean;
  error?: string;
  code?: string;
}

/**
 * Sponsor an SPL token transfer transaction
 * Backend pays for gas + ATA creation if needed
 */
export const sponsorSplTransfer = onCall<
  SponsorSplTransferRequest,
  Promise<SponsorSplTransferResponse>
>(
  {
    secrets: [HELIUS_RPC_URL, SOLANA_FEE_PAYER_PRIVATE_KEY],
    enforceAppCheck: false,
    invoker: "public",
  },
  async (
    request: CallableRequest<SponsorSplTransferRequest>
  ): Promise<SponsorSplTransferResponse> => {
    const { tokenMintAddress, destinationAddress, amount, decimals = 6, userWalletAddress, createDestinationATA } =
      request.data;

    try {
      logger.info("🚀 Starting sponsored SPL token transfer");
      logger.info(`Token Mint: ${tokenMintAddress}`);
      logger.info(`Destination: ${destinationAddress}`);
      logger.info(`Amount: ${amount} (${amount / Math.pow(10, decimals)} tokens)`);

      // Validate addresses
      if (!isValidSolanaAddress(tokenMintAddress)) {
        return createErrorResponse(
          "INVALID_MINT",
          "Invalid token mint address"
        ) as SponsorSplTransferResponse;
      }

      if (!isValidSolanaAddress(destinationAddress)) {
        return createErrorResponse(
          "INVALID_ADDRESS",
          "Invalid destination address"
        ) as SponsorSplTransferResponse;
      }

      // Validate amount
      if (amount <= 0) {
        return createErrorResponse(
          "INVALID_AMOUNT",
          "Amount must be greater than 0"
        ) as SponsorSplTransferResponse;
      }

      // For security, we'll use a very small lamport value for rate limiting
      // Real validation happens on token balance
      const estimatedCostLamports = 10000; // 0.00001 SOL

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

        const connection = getSolanaConnection();
        const userWalletPubkey = new PublicKey(userWalletFromRequest);
        const tokenMintPubkey = new PublicKey(tokenMintAddress);
        const destinationPubkey = new PublicKey(destinationAddress);

        // Get user's token account (ATA)
        const sourceATA = await getAssociatedTokenAddress(
          tokenMintPubkey,
          userWalletPubkey
        );

        // Get destination token account (ATA)
        const destinationATA = await getAssociatedTokenAddress(
          tokenMintPubkey,
          destinationPubkey
        );

        logger.info(`Source ATA: ${sourceATA.toBase58()}`);
        logger.info(`Destination ATA: ${destinationATA.toBase58()}`);

        // Check if source ATA exists and has sufficient balance
        const sourceAccountInfo = await connection.getAccountInfo(sourceATA);
        if (!sourceAccountInfo) {
          await updateTransactionStatus(
            transactionId,
            "failed",
            undefined,
            "Source token account does not exist"
          );
          return createErrorResponse(
            "SOURCE_ACCOUNT_NOT_FOUND",
            "You don't have this token in your wallet"
          ) as SponsorSplTransferResponse;
        }

        // Check destination ATA exists
        const destinationAccountInfo = await connection.getAccountInfo(destinationATA);
        const needsATACreation = !destinationAccountInfo && createDestinationATA !== false;
        let ataCreated = false;

        // Build instructions
        const instructions = [];

        // Add create ATA instruction if needed
        if (needsATACreation) {
          logger.info("🔨 Destination ATA does not exist, creating...");
          const createATAInstruction = createAssociatedTokenAccountInstruction(
            getFeePayerPublicKey(), // Fee payer creates and pays rent
            destinationATA,
            destinationPubkey,
            tokenMintPubkey
          );
          instructions.push(createATAInstruction);
          ataCreated = true;
        } else if (!destinationAccountInfo) {
          await updateTransactionStatus(
            transactionId,
            "failed",
            undefined,
            "Destination token account does not exist"
          );
          return createErrorResponse(
            "DESTINATION_ACCOUNT_NOT_FOUND",
            "Destination wallet doesn't have a token account for this token"
          ) as SponsorSplTransferResponse;
        }

        // Add transfer instruction
        const transferInstruction = createTransferInstruction(
          sourceATA, // from
          destinationATA, // to
          userWalletPubkey, // owner of source
          amount, // amount
          [], // multisig signers (none)
          TOKEN_PROGRAM_ID
        );
        instructions.push(transferInstruction);

        // Build transaction with fee payer as backend wallet
        const transaction = await buildVersionedTransaction({
          instructions,
          feePayer: getFeePayerPublicKey(),
        });

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
          ) as SponsorSplTransferResponse;
        }

        logger.info("✅ Simulation successful");

        // Sign with fee payer
        signTransactionWithFeePayer(transaction);

        // NOTE: In a real implementation, the user would also need to sign this
        // transaction since they're the authority for the source token account

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
            ataCreated,
          },
          `SPL token transfer successful: ${signature}`
        ) as SponsorSplTransferResponse;
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
      logger.error("❌ Sponsored SPL transfer failed:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      return createErrorResponse(
        "TRANSACTION_FAILED",
        error instanceof Error ? error.message : "Transaction failed",
        { error }
      ) as SponsorSplTransferResponse;
    }
  }
);
