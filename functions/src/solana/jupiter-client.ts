import axios from "axios";
import { PublicKey, VersionedTransaction } from "@solana/web3.js";
import * as logger from "firebase-functions/logger";
import { retryWithBackoff } from "../solana-utils";

const JUPITER_API_BASE_URL = "https://quote-api.jup.ag/v6";

export interface JupiterQuoteParams {
  inputMint: string; // Token mint address to swap from
  outputMint: string; // Token mint address to swap to
  amount: number; // Amount in smallest unit (e.g., lamports for SOL)
  slippageBps?: number; // Slippage tolerance in basis points (default: 50 = 0.5%)
  onlyDirectRoutes?: boolean; // Only direct routes (default: false)
  asLegacyTransaction?: boolean; // Return legacy transaction instead of versioned
}

export interface JupiterQuoteResponse {
  inputMint: string;
  inAmount: string;
  outputMint: string;
  outAmount: string;
  otherAmountThreshold: string;
  swapMode: string;
  slippageBps: number;
  priceImpactPct: string;
  routePlan: Array<{
    swapInfo: {
      ammKey: string;
      label: string;
      inputMint: string;
      outputMint: string;
      inAmount: string;
      outAmount: string;
      feeAmount: string;
      feeMint: string;
    };
    percent: number;
  }>;
}

export interface JupiterSwapParams {
  quoteResponse: JupiterQuoteResponse;
  userPublicKey: string;
  wrapAndUnwrapSol?: boolean;
  feeAccount?: string;
  dynamicComputeUnitLimit?: boolean;
  prioritizationFeeLamports?: number;
}

export interface JupiterSwapResponse {
  swapTransaction: string; // Base64 encoded transaction
  lastValidBlockHeight: number;
  prioritizationFeeLamports?: number;
}

/**
 * Jupiter API Client for Solana token swaps
 */
export class JupiterClient {
  private client: any;

  constructor() {
    this.client = axios.create({
      baseURL: JUPITER_API_BASE_URL,
      timeout: 30000,
      headers: {
        "Content-Type": "application/json",
      },
    });
  }

  /**
   * Get a quote for a token swap
   */
  async getQuote(params: JupiterQuoteParams): Promise<JupiterQuoteResponse> {
    return retryWithBackoff(async () => {
      try {
        logger.info(`Fetching Jupiter quote: ${params.inputMint} -> ${params.outputMint}`);

        const response = await this.client.get("/quote", {
          params: {
            inputMint: params.inputMint,
            outputMint: params.outputMint,
            amount: params.amount,
            slippageBps: params.slippageBps || 50,
            onlyDirectRoutes: params.onlyDirectRoutes || false,
            asLegacyTransaction: params.asLegacyTransaction || false,
          },
        });

        logger.info(
          `Jupiter quote received: ${response.data.inAmount} -> ${response.data.outAmount}`
        );
        logger.info(`Price impact: ${response.data.priceImpactPct}%`);

        return response.data;
      } catch (error) {
        if ((error as any).response) {
          logger.error("Jupiter quote API error:", {
            status: error.response?.status,
            data: error.response?.data,
          });
          throw new Error(
            `Jupiter quote failed: ${error.response?.data?.error || error.message}`
          );
        }
        throw error;
      }
    }, 3);
  }

  /**
   * Get swap transaction from quote
   */
  async getSwapTransaction(params: JupiterSwapParams): Promise<JupiterSwapResponse> {
    return retryWithBackoff(async () => {
      try {
        logger.info(`Building Jupiter swap transaction for user: ${params.userPublicKey}`);

        const response = await this.client.post("/swap", {
          quoteResponse: params.quoteResponse,
          userPublicKey: params.userPublicKey,
          wrapAndUnwrapSol: params.wrapAndUnwrapSol !== false, // Default true
          dynamicComputeUnitLimit: params.dynamicComputeUnitLimit !== false, // Default true
          ...(params.feeAccount && { feeAccount: params.feeAccount }),
          ...(params.prioritizationFeeLamports && {
            prioritizationFeeLamports: params.prioritizationFeeLamports,
          }),
        });

        logger.info("✅ Jupiter swap transaction built successfully");
        return response.data;
      } catch (error) {
        if ((error as any).response) {
          logger.error("Jupiter swap API error:", {
            status: error.response?.status,
            data: error.response?.data,
          });
          throw new Error(
            `Jupiter swap failed: ${error.response?.data?.error || error.message}`
          );
        }
        throw error;
      }
    }, 3);
  }

  /**
   * Get quote and swap transaction in one call
   */
  async getQuoteAndSwap(
    params: JupiterQuoteParams & { userPublicKey: string; feeAccount?: string }
  ): Promise<{ quote: JupiterQuoteResponse; swap: JupiterSwapResponse }> {
    try {
      // Get quote
      const quote = await this.getQuote(params);

      // Get swap transaction
      const swap = await this.getSwapTransaction({
        quoteResponse: quote,
        userPublicKey: params.userPublicKey,
        feeAccount: params.feeAccount,
      });

      return { quote, swap };
    } catch (error) {
      logger.error("Jupiter quote and swap failed:", error);
      throw error;
    }
  }

  /**
   * Deserialize swap transaction from base64
   */
  deserializeSwapTransaction(swapTransactionBase64: string): VersionedTransaction {
    try {
      const buffer = Buffer.from(swapTransactionBase64, "base64");
      const transaction = VersionedTransaction.deserialize(buffer);
      logger.info("✅ Swap transaction deserialized successfully");
      return transaction;
    } catch (error) {
      logger.error("Failed to deserialize swap transaction:", error);
      throw new Error("Failed to deserialize swap transaction");
    }
  }

  /**
   * Get token price from Jupiter
   */
  async getTokenPrice(tokenMint: string): Promise<{ price: number; timestamp: number }> {
    try {
      const response = await axios.get(`https://price.jup.ag/v4/price`, {
        params: { ids: tokenMint },
      });

      const priceData = (response as any).data.data[tokenMint];
      if (!priceData) {
        throw new Error(`Price not found for token: ${tokenMint}`);
      }

      return {
        price: priceData.price,
        timestamp: Date.now(),
      };
    } catch (error) {
      logger.error("Failed to get token price:", error);
      throw error;
    }
  }

  /**
   * Calculate expected output amount with slippage
   */
  calculateMinimumOutput(
    outputAmount: string,
    slippageBps: number = 50
  ): { minimum: string; slippagePercent: number } {
    const amount = BigInt(outputAmount);
    const slippageFactor = BigInt(10000 - slippageBps);
    const minimum = (amount * slippageFactor) / BigInt(10000);

    return {
      minimum: minimum.toString(),
      slippagePercent: slippageBps / 100,
    };
  }

  /**
   * Validate token addresses
   */
  validateTokenMints(inputMint: string, outputMint: string): void {
    try {
      new PublicKey(inputMint);
      new PublicKey(outputMint);

      if (inputMint === outputMint) {
        throw new Error("Input and output mints cannot be the same");
      }
    } catch (error) {
      throw new Error(
        `Invalid token mint address: ${error instanceof Error ? error.message : "Unknown error"}`
      );
    }
  }
}

// Common token mints for convenience
export const COMMON_TOKEN_MINTS = {
  SOL: "So11111111111111111111111111111111111111112",
  USDC: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
  USDT: "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
  BONK: "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263",
  WIF: "EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm",
};

/**
 * Helper function to get readable token name
 */
export function getTokenName(mint: string): string {
  const tokenEntry = Object.entries(COMMON_TOKEN_MINTS).find(
    ([_, address]) => address === mint
  );
  return tokenEntry ? tokenEntry[0] : mint.substring(0, 8);
}

// Export singleton instance
export const jupiterClient = new JupiterClient();
