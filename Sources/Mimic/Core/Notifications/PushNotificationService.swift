import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "PushNotificationService")

/// Service for managing push notification tokens
@MainActor
class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()

    private let db = Firestore.firestore()
    private var currentToken: String?

    private init() {}

    /// Update FCM token in Firestore for current user
    func updateFCMToken(_ token: String) async {
        // Don't update if token hasn't changed
        guard token != currentToken else { return }

        guard let userId = Auth.auth().currentUser?.uid else {
            logger.warning("⚠️ Cannot update FCM token - no authenticated user")
            return
        }

        do {
            try await db.collection("users").document(userId).setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            currentToken = token
            logger.info("✅ FCM token updated for user \(userId)")
        } catch {
            logger.error("❌ Failed to update FCM token: \(error.localizedDescription)")
        }
    }

    /// Clear FCM token (call on logout)
    func clearToken() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(userId).updateData([
                "fcmToken": FieldValue.delete()
            ])
            currentToken = nil
            logger.info("🧹 FCM token cleared for user \(userId)")
        } catch {
            logger.error("❌ Failed to clear FCM token: \(error.localizedDescription)")
        }
    }
}
