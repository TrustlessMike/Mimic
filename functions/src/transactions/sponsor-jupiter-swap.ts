import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { PublicKey } from "@solana/web3.js";
import * as logger from "firebase-functions/logger";
import {
  HELIUS_RPC_URL,
  SOLANA_FEE_PAYER_PRIVATE_KEY,
  getFeePayerPublicKey,
} from "../solana-config";
import {
  signTransactionWithFeePayer,
  sendAndConfirmTransactionWithRetry,
  simulateTransaction,
} from "../solana/transaction-builder";
import {
  performSecurityChecks,
  updateTransactionStatus,
} from "../middleware/transaction-security";
import { createErrorResponse, createSuccessResponse } from "../solana-utils";
import { jupiterClient, getTokenName } from "../solana/jupiter-client";

interface SponsorJupiterSwapRequest {
  inputMint: string; // Token to swap from
  outputMint: string; // Token to swap to
  amount: number; // Amount in smallest unit
  userWalletAddress?: string; // Optional - will get from Firestore if not provided
  slippageBps?: number; // Slippage in basis points (default: 50 = 0.5%)
  onlyDirectRoutes?: boolean;
}

interface SponsorJupiterSwapResponse {
  success: boolean;
  signature?: string;
  explorerUrl?: string;
  inputAmount?: string;
  outputAmount?: string;
  priceImpact?: string;
  error?: string;
  code?: string;
}

/**
 * Sponsor a Jupiter swap transaction
 * Backend pays for all gas fees
 */
export const sponsorJupiterSwap = onCall<
  SponsorJupiterSwapRequest,
  Promise<SponsorJupiterSwapResponse>
>(
  {
    secrets: [HELIUS_RPC_URL, SOLANA_FEE_PAYER_PRIVATE_KEY],
    enforceAppCheck: false,
    invoker: "public",
    timeoutSeconds: 540, // 9 minutes (Jupiter can be slow)
  },
  async (
    request: CallableRequest<SponsorJupiterSwapRequest>
  ): Promise<SponsorJupiterSwapResponse> => {
    const { inputMint, outputMint, amount, userWalletAddress, slippageBps, onlyDirectRoutes } = request.data;

    try {
      logger.info("🚀 Starting sponsored Jupiter swap");
      logger.info(
        `Swap: ${getTokenName(inputMint)} -> ${getTokenName(outputMint)}`
      );
      logger.info(`Amount: ${amount}`);

      // Validate token mints
      try {
        jupiterClient.validateTokenMints(inputMint, outputMint);
      } catch (error) {
        return createErrorResponse(
          "INVALID_MINTS",
          error instanceof Error ? error.message : "Invalid token mints"
        ) as SponsorJupiterSwapResponse;
      }

      // Estimate cost for security checks (Jupiter swaps can vary, use conservative estimate)
      const estimatedCostLamports = 50000; // 0.00005 SOL

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

        // Step 1: Get quote from Jupiter
        logger.info("📊 Fetching Jupiter quote...");
        const quote = await jupiterClient.getQuote({
          inputMint,
          outputMint,
          amount,
          slippageBps: slippageBps || 50,
          onlyDirectRoutes: onlyDirectRoutes || false,
        });

        logger.info(`Quote received:`);
        logger.info(`  Input: ${quote.inAmount} ${getTokenName(inputMint)}`);
        logger.info(`  Output: ${quote.outAmount} ${getTokenName(outputMint)}`);
        logger.info(`  Price Impact: ${quote.priceImpactPct}%`);
        logger.info(`  Route: ${quote.routePlan.length} steps`);

        // Warn if price impact is high
        const priceImpact = parseFloat(quote.priceImpactPct);
        if (priceImpact > 1.0) {
          logger.warn(`⚠️ High price impact: ${priceImpact}%`);
        }

        // Step 2: Get swap transaction from Jupiter
        logger.info("🔨 Building swap transaction...");
        const swap = await jupiterClient.getSwapTransaction({
          quoteResponse: quote,
          userPublicKey: userWalletFromRequest,
          wrapAndUnwrapSol: true,
          dynamicComputeUnitLimit: true,
        });

        // Step 3: Deserialize the transaction
        const transaction = jupiterClient.deserializeSwapTransaction(
          swap.swapTransaction
        );

        logger.info("✅ Swap transaction deserialized");

        // Modify transaction to use our fee payer
        // Note: Jupiter transactions already come with a fee payer set,
        // but we want to use our backend wallet instead

        // For versioned transactions, we need to decompress, modify, and recompress
        const { TransactionMessage } = await import("@solana/web3.js");
        const decompiledMessage = TransactionMessage.decompile(transaction.message);

        // Change fee payer to our backend wallet
        decompiledMessage.payerKey = getFeePayerPublicKey();

        // Recompile
        const modifiedMessage = decompiledMessage.compileToV0Message();
        transaction.message = modifiedMessage;

        // Step 4: Simulate transaction
        logger.info("🔍 Simulating swap transaction...");
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
            `Swap simulation failed: ${simulation.error}`,
            {
              logs: simulation.logs,
              quote: {
                inputAmount: quote.inAmount,
                outputAmount: quote.outAmount,
                priceImpact: quote.priceImpactPct,
              },
            }
          ) as SponsorJupiterSwapResponse;
        }

        logger.info("✅ Simulation successful");

        // Step 5: Sign with fee payer
        signTransactionWithFeePayer(transaction);

        // NOTE: User also needs to sign as they're the authority for token accounts

        // Step 6: Send and confirm
        logger.info("📤 Sending swap transaction to network...");
        const signature = await sendAndConfirmTransactionWithRetry(transaction, {
          maxRetries: 3,
        });

        logger.info(`✅ Swap confirmed: ${signature}`);

        // Update transaction status with swap details
        await updateTransactionStatus(transactionId, "success", signature);

        const explorerUrl = `https://solscan.io/tx/${signature}?cluster=mainnet`;

        return createSuccessResponse(
          {
            signature,
            explorerUrl,
            inputAmount: quote.inAmount,
            outputAmount: quote.outAmount,
            priceImpact: quote.priceImpactPct,
          },
          `Jupiter swap successful: ${signature}`
        ) as SponsorJupiterSwapResponse;
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
      logger.error("❌ Sponsored Jupiter swap failed:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      return createErrorResponse(
        "SWAP_FAILED",
        error instanceof Error ? error.message : "Swap failed",
        { error }
      ) as SponsorJupiterSwapResponse;
    }
  }
);
