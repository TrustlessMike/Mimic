import Foundation

/// Centralized app configuration
enum AppConfiguration {
    // MARK: - Privy Configuration
    enum Privy {
        static let appId = "cmh5i82000072jl0cixsq20k7"
        static let clientId = "client-WY6SJ3DpaUXxFWCWdTG6FANZ2zzDxkaF9kUWjZTqDM5RG"
        static let urlScheme = "mimic"
    }

    // MARK: - Firebase Configuration
    enum Firebase {
        static let projectId = "mimic-app"
        static let functionName = "createFirebaseCustomToken"
        static let region = "us-central1"
    }

    // MARK: - App Configuration
    enum App {
        static var bundleId: String { Bundle.main.bundleIdentifier ?? "com.syndicatemike.Mimic" }
        static let appName = "Mimic"
    }

    // MARK: - Legal & Support URLs
    enum Legal {
        static let termsOfServiceURL = "https://mimic.app/terms"
        static let privacyPolicyURL = "https://mimic.app/privacy"
        static let supportURL = "https://mimic.app/support"
    }
}
