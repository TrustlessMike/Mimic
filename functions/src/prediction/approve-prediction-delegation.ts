import * as logger from "firebase-functions/logger";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {
  PRIVY_APP_ID,
  PRIVY_APP_SECRET,
  PRIVY_PREDICTION_AUTH_KEY,
  createPredictionCopyPolicy,
  getPredictionKeyQuorumId,
  getWalletIdFromDid,
} from "../config/privy-config";

/**
 * Prediction copy trading delegation configuration
 */
export interface PredictionDelegationConfig {
  userId: string;
  status: "pending" | "active" | "revoked" | "expired";

  // Copy trading settings
  maxCopyAmountUsd: number;      // Max USD per copy trade
  copyPercentage: number;        // % of original bet to copy
  minBetSizeUsd: number;         // Min bet size to trigger copy

  // Security
  expiresAt: FirebaseFirestore.Timestamp;

  // Privy-specific
  privyPolicyId: string;
  privyKeyQuorumId: string;

  // Tracking
  createdAt: FirebaseFirestore.Timestamp;
  totalCopiesExecuted: number;
  totalVolumeUsd: number;
}

/**
 * Request to approve prediction copy trading delegation
 */
interface ApprovePredictionDelegationRequest {
  maxCopyAmountUsd: number;      // Max USD per copy trade (e.g., 50)
  copyPercentage: number;        // % of original bet (e.g., 10)
  minBetSizeUsd: number;         // Min original bet size (e.g., 5)
  expirationDays: number;        // 30, 90, or 365
  privyAccessToken: string;      // User's Privy access token
}

/**
 * Cloud Function: Approve delegation for prediction copy trading
 *
 * This enables server-side execution of prediction market bets on behalf of the user.
 * Uses a separate authorization key specifically for prediction copy trading.
 *
 * Flow:
 * 1. Validate settings (max amount, percentage, etc.)
 * 2. Get user's wallet ID from Privy
 * 3. Create Privy policy for Jupiter Prediction Market
 * 4. Add prediction auth key as additional signer with policy
 * 5. Store delegation config in Firestore
 */
export const approvePredictionDelegation = onCall(
  {
    secrets: [
      PRIVY_APP_ID,
      PRIVY_APP_SECRET,
      PRIVY_PREDICTION_AUTH_KEY,
    ],
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const data = request.data as ApprovePredictionDelegationRequest;

    // Validate settings
    if (data.maxCopyAmountUsd <= 0 || data.maxCopyAmountUsd > 1000) {
      throw new HttpsError(
        "invalid-argument",
        "Max copy amount must be between $1 and $1000"
      );
    }

    if (data.copyPercentage <= 0 || data.copyPercentage > 100) {
      throw new HttpsError(
        "invalid-argument",
        "Copy percentage must be between 1% and 100%"
      );
    }

    if (data.minBetSizeUsd < 0) {
      throw new HttpsError(
        "invalid-argument",
        "Min bet size must be positive"
      );
    }

    if (![30, 90, 365].includes(data.expirationDays)) {
      throw new HttpsError(
        "invalid-argument",
        "Expiration must be 30, 90, or 365 days"
      );
    }

    if (!data.privyAccessToken) {
      throw new HttpsError(
        "invalid-argument",
        "Privy access token required"
      );
    }

    logger.info(`📝 Creating prediction copy delegation for user ${userId}`);
    logger.info(`   Max copy: $${data.maxCopyAmountUsd}`);
    logger.info(`   Copy %: ${data.copyPercentage}%`);
    logger.info(`   Min bet: $${data.minBetSizeUsd}`);
    logger.info(`   Expires in: ${data.expirationDays} days`);

    const db = getFirestore();

    // Get user's wallet info
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();

    if (!userData?.walletAddress) {
      throw new HttpsError("failed-precondition", "User wallet not found");
    }

    if (!userData?.privyUserId) {
      throw new HttpsError(
        "failed-precondition",
        "Privy user ID not found"
      );
    }

    const appId = PRIVY_APP_ID.value().trim();
    const appSecret = PRIVY_APP_SECRET.value().trim();

    // Get wallet ID
    const walletId = await getWalletIdFromDid(
      userData.privyUserId,
      appId,
      appSecret,
      userData.walletAddress
    );
    logger.info(`✅ Resolved wallet ID: ${walletId}`);

    try {
      // Calculate expiration
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + data.expirationDays);
      const expirationTimestamp = Math.floor(expiresAt.getTime() / 1000);

      // Create Privy policy for prediction markets
      const shortName = `pred-${userId.slice(-8)}-${Date.now().toString().slice(-6)}`;
      logger.info("📋 Creating prediction policy...");

      const policyId = await createPredictionCopyPolicy({
        name: shortName,
        maxCopyAmountUsd: data.maxCopyAmountUsd,
        expirationTimestamp,
      });

      logger.info(`✅ Prediction policy created: ${policyId}`);

      // Get prediction key quorum ID
      const keyQuorumId = getPredictionKeyQuorumId();

      // Add prediction auth key as additional signer with policy
      logger.info("📝 Adding prediction auth key to wallet...");

      const updateResponse = await fetch(`https://api.privy.io/v1/wallets/${walletId}`, {
        method: "PATCH",
        headers: {
          "Authorization": `Basic ${Buffer.from(`${appId}:${appSecret}`).toString("base64")}`,
          "privy-app-id": appId,
          "Content-Type": "application/json",
          "privy-user-access-token": data.privyAccessToken,
        },
        body: JSON.stringify({
          additional_signers: [
            {
              signer_id: keyQuorumId,
              override_policy_ids: [policyId],
            },
          ],
        }),
      });

      if (!updateResponse.ok) {
        const error = await updateResponse.text();
        logger.error(`❌ Failed to add auth key: ${error}`);
        throw new HttpsError(
          "internal",
          `Failed to set up delegation: ${error}`
        );
      }

      const updatedWallet = await updateResponse.json();
      logger.info("✅ Prediction auth key added to wallet");
      logger.info(`   Signers: ${JSON.stringify(updatedWallet.additional_signers)}`);

      // Clean up old prediction delegations
      logger.info("🧹 Cleaning up old delegations...");

      const oldDelegations = await db
        .collection("users")
        .doc(userId)
        .collection("prediction_delegations")
        .where("status", "in", ["pending", "revoked", "expired"])
        .get();

      if (!oldDelegations.empty) {
        await Promise.all(oldDelegations.docs.map(doc => doc.ref.delete()));
        logger.info(`   Deleted ${oldDelegations.size} old delegation(s)`);
      }

      // Revoke any active delegations
      const activeDelegations = await db
        .collection("users")
        .doc(userId)
        .collection("prediction_delegations")
        .where("status", "==", "active")
        .get();

      if (!activeDelegations.empty) {
        await Promise.all(
          activeDelegations.docs.map(doc =>
            doc.ref.update({status: "revoked"})
          )
        );
        logger.info(`   Revoked ${activeDelegations.size} active delegation(s)`);
      }

      // Create new delegation config
      const delegationConfig: Partial<PredictionDelegationConfig> = {
        userId,
        status: "active",
        maxCopyAmountUsd: data.maxCopyAmountUsd,
        copyPercentage: data.copyPercentage,
        minBetSizeUsd: data.minBetSizeUsd,
        expiresAt: expiresAt as any,
        privyPolicyId: policyId,
        privyKeyQuorumId: keyQuorumId,
        createdAt: FieldValue.serverTimestamp() as any,
        totalCopiesExecuted: 0,
        totalVolumeUsd: 0,
      };

      const delegationRef = await db
        .collection("users")
        .doc(userId)
        .collection("prediction_delegations")
        .add(delegationConfig);

      // Update user document with delegation status
      await db.collection("users").doc(userId).update({
        predictionDelegationActive: true,
        predictionDelegationId: delegationRef.id,
        predictionMaxCopyUsd: data.maxCopyAmountUsd,
        predictionCopyPercentage: data.copyPercentage,
        predictionMinBetUsd: data.minBetSizeUsd,
        predictionDelegationExpiresAt: expiresAt,
      });

      logger.info(`✅ Prediction delegation created: ${delegationRef.id}`);

      return {
        success: true,
        delegationId: delegationRef.id,
        policyId,
        keyQuorumId,
        status: "active",
        expiresAt: expiresAt.toISOString(),
        message: "Prediction copy trading is now enabled!",
      };

    } catch (error: any) {
      logger.error("❌ Failed to create prediction delegation:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        "internal",
        `Failed to create delegation: ${error.message || error}`
      );
    }
  }
);

/**
 * Cloud Function: Revoke prediction copy trading delegation
 */
export const revokePredictionDelegation = onCall(
  {
    secrets: [PRIVY_APP_ID, PRIVY_APP_SECRET],
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    logger.info(`🚫 Revoking prediction delegation for user ${userId}`);

    const db = getFirestore();

    // Find active delegation
    const activeDelegations = await db
      .collection("users")
      .doc(userId)
      .collection("prediction_delegations")
      .where("status", "==", "active")
      .get();

    if (activeDelegations.empty) {
      throw new HttpsError("not-found", "No active delegation found");
    }

    // Revoke all active delegations
    await Promise.all(
      activeDelegations.docs.map(doc =>
        doc.ref.update({
          status: "revoked",
          revokedAt: FieldValue.serverTimestamp(),
        })
      )
    );

    // Update user document
    await db.collection("users").doc(userId).update({
      predictionDelegationActive: false,
      predictionDelegationId: null,
    });

    logger.info(`✅ Prediction delegation revoked`);

    return {
      success: true,
      message: "Prediction copy trading has been disabled",
    };
  }
);
