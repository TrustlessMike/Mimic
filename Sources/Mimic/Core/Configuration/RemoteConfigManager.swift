import Foundation
import FirebaseRemoteConfig
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "RemoteConfig")

/// Manager for Firebase Remote Config
/// Provides secure access to remote configuration values like API keys
@MainActor
class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()

    private let remoteConfig: RemoteConfig
    @Published private(set) var isFetched = false

    // MARK: - Remote Config Keys

    private enum ConfigKey: String {
        case heliusRpcUrl = "helius_rpc_url"
        case birdeyeApiKey = "birdeye_api_key"
        case privyAppId = "privy_app_id"
        case privyAppClientId = "privy_app_client_id"
        case maxTransactionRetries = "max_transaction_retries"
    }

    // MARK: - Default Values

    private let defaults: [String: NSObject] = [
        ConfigKey.heliusRpcUrl.rawValue: "" as NSObject,
        ConfigKey.birdeyeApiKey.rawValue: "" as NSObject,
        ConfigKey.privyAppId.rawValue: "" as NSObject,
        ConfigKey.privyAppClientId.rawValue: "" as NSObject,
        ConfigKey.maxTransactionRetries.rawValue: 3 as NSObject,
    ]

    private init() {
        self.remoteConfig = RemoteConfig.remoteConfig()

        // Configure fetch settings
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600 // 1 hour in production
        #if DEBUG
        settings.minimumFetchInterval = 0 // No caching in debug
        #endif

        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(defaults)

        logger.debug("RemoteConfigManager initialized")
    }

    // MARK: - Public API

    /// Fetch and activate remote config values
    func fetchAndActivate() async throws {
        logger.debug("Fetching remote config...")

        let status = try await remoteConfig.fetchAndActivate()

        switch status {
        case .successFetchedFromRemote:
            logger.debug("Remote config fetched from server")
        case .successUsingPreFetchedData:
            logger.debug("Remote config using cached data")
        case .error:
            logger.error("❌ Remote config fetch failed")
            throw RemoteConfigError.fetchFailed
        @unknown default:
            logger.warning("⚠️ Unknown remote config status")
        }

        await MainActor.run {
            self.isFetched = true
        }
    }

    /// Get Helius RPC URL
    var heliusRpcUrl: String {
        remoteConfig.configValue(forKey: ConfigKey.heliusRpcUrl.rawValue).stringValue ?? ""
    }

    /// Get Birdeye API key for price charts
    var birdeyeApiKey: String {
        remoteConfig.configValue(forKey: ConfigKey.birdeyeApiKey.rawValue).stringValue ?? ""
    }

    /// Get Privy App ID
    var privyAppId: String {
        remoteConfig.configValue(forKey: ConfigKey.privyAppId.rawValue).stringValue ?? ""
    }

    /// Get Privy App Client ID
    var privyAppClientId: String {
        remoteConfig.configValue(forKey: ConfigKey.privyAppClientId.rawValue).stringValue ?? ""
    }

    /// Get maximum transaction retries
    var maxTransactionRetries: Int {
        remoteConfig.configValue(forKey: ConfigKey.maxTransactionRetries.rawValue).numberValue.intValue
    }
}

// MARK: - Errors

enum RemoteConfigError: LocalizedError {
    case fetchFailed
    case notFetched

    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to fetch remote configuration"
        case .notFetched:
            return "Remote configuration not yet fetched"
        }
    }
}
