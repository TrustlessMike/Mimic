import Foundation

/// Centralized app configuration
enum AppConfiguration {
    // MARK: - Privy Configuration
    enum Privy {
        static let appId = "cmh5i82000072jl0cixsq20k7"
        static let clientId = "client-WY6SJ3DpaUXxFWCWdTG6FANZ2zzDxkaF9kUWjZTqDM5RG"
        static let urlScheme = "wickett"
    }

    // MARK: - Firebase Configuration
    enum Firebase {
        static let projectId = "wickett-13423"
        static let functionName = "createFirebaseCustomToken"
        static let region = "us-central1"
    }

    // MARK: - App Configuration
    enum App {
        static let bundleId = "com.syndicatemike.Wickett"
        static let appName = "Wickett"
    }

    // MARK: - Legal & Support URLs
    enum Legal {
        static let termsOfServiceURL = "https://wickett.app/terms"
        static let privacyPolicyURL = "https://wickett.app/privacy"
        static let supportURL = "https://wickett.app/support"
    }
}
