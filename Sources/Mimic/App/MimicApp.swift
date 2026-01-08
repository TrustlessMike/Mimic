import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import FirebaseCrashlytics
import UIKit

@main
struct MimicApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authCoordinator = AuthCoordinator.shared

    init() {
        // Initialize Firebase
        FirebaseApp.configure()

        // Configure Firebase Auth for persistent sessions
        // This enables automatic token refresh for up to 400 days (matching Privy)
        Auth.auth().useAppLanguage()

        // Configure Crashlytics
        configureCrashlytics()
    }

    private func configureCrashlytics() {
        // Enable Crashlytics collection (can be disabled via user settings)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // Set app version info
        Crashlytics.crashlytics().setCustomValue(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            forKey: "app_version"
        )
        Crashlytics.crashlytics().setCustomValue(
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            forKey: "build_number"
        )

        #if DEBUG
        // Disable Crashlytics in debug builds to avoid noise
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authCoordinator)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Handle Privy deep links for authentication callbacks
        #if DEBUG
        print("Received deep link: \(url)")
        #endif
        // Privy SDK will handle privy:// scheme URLs automatically
    }
}

// MARK: - App Delegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set messaging delegate
        Messaging.messaging().delegate = self

        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Register for remote notifications
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - APNs Token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass device token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        #if DEBUG
        print("APNs token registered")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("Failed to register for remote notifications: \(error)")
        #endif
        error.report(context: "Push notification registration")
    }

    // MARK: - Firebase Messaging Delegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        #if DEBUG
        print("FCM token received")
        #endif

        // Store FCM token in Firestore for the current user
        Task {
            await PushNotificationService.shared.updateFCMToken(token)
        }
    }

    // MARK: - Foreground Notification Handling

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap - e.g., navigate to payment request
        if let requestId = userInfo["requestId"] as? String {
            #if DEBUG
            print("User tapped notification for request: \(requestId)")
            #endif
            // TODO: Navigate to request detail
        }

        completionHandler()
    }
}