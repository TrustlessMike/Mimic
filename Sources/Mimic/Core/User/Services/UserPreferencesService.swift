import Foundation
import FirebaseFirestore
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "UserPreferencesService")

/// Service for managing user preferences in Firebase
@MainActor
class UserPreferencesService: ObservableObject {
    static let shared = UserPreferencesService()

    @Published var preferences: UserPreferences

    private let db = Firestore.firestore()
    private var currentUserId: String?

    /// Cache timestamp - avoid refetching if data is fresh
    private var lastPreferencesFetch: Date?
    private let preferencesCacheSeconds: TimeInterval = 60

    private init() {
        // Initialize with defaults
        self.preferences = UserPreferences()
    }

    // MARK: - Load Preferences

    /// Load user preferences from Firebase
    /// - Parameters:
    ///   - userId: The user ID to load preferences for
    ///   - force: If true, bypasses cache and forces a refresh
    func loadPreferences(userId: String, force: Bool = false) async throws {
        // Check cache validity (skip if data is fresh and same user)
        if !force,
           userId == currentUserId,
           let lastFetch = lastPreferencesFetch,
           Date().timeIntervalSince(lastFetch) < preferencesCacheSeconds {
            logger.info("💾 Using cached preferences (age: \(Int(Date().timeIntervalSince(lastFetch)))s)")
            return
        }

        self.currentUserId = userId

        logger.info("📥 Loading preferences for user: \(userId)")

        let docRef = db.collection("users").document(userId)
        let document = try await docRef.getDocument()

        if document.exists, let data = document.data() {
            logger.info("✅ Preferences document found")

            if let prefs = UserPreferences.from(dictionary: data) {
                await MainActor.run {
                    self.preferences = prefs
                }
                lastPreferencesFetch = Date()
                logger.info("✅ Loaded preferences: currency=\(prefs.localCurrency.rawValue)")
            } else {
                // Data exists but parsing failed, use defaults
                logger.warning("⚠️ Failed to parse preferences, using defaults")
                await savePreferences(preferences)
            }
        } else {
            // No preferences exist, create defaults
            logger.info("📝 No preferences found, creating defaults")
            await savePreferences(preferences)
        }

        lastPreferencesFetch = Date()
    }

    // MARK: - Save Preferences

    /// Save user preferences to Firebase
    func savePreferences(_ prefs: UserPreferences) async {
        guard let userId = currentUserId else {
            logger.error("❌ Cannot save preferences: no userId set")
            return
        }

        logger.info("💾 Saving preferences for user: \(userId)")

        var prefsToSave = prefs
        prefsToSave.updatedAt = Date()

        let docRef = db.collection("users").document(userId)

        do {
            try await docRef.setData(prefsToSave.toDictionary(), merge: true)

            await MainActor.run {
                self.preferences = prefsToSave
            }

            // Update shared data for iMessage extension (future use)
            SharedDataManager.shared.updatePreferredToken(prefsToSave.preferredPaymentToken ?? "SOL")

            logger.info("✅ Preferences saved successfully")
        } catch {
            logger.error("❌ Failed to save preferences: \(error.localizedDescription)")
        }
    }

    // MARK: - Update Individual Settings

    /// Update local currency preference
    func updateLocalCurrency(_ currency: FiatCurrency) async {
        logger.info("💱 Updating currency to: \(currency.rawValue)")

        var updated = preferences
        updated.localCurrency = currency

        await savePreferences(updated)
    }

    /// Update preferred payment token
    func updatePreferredPaymentToken(_ token: String?) async {
        logger.info("💳 Updating preferred payment token to: \(token ?? "nil")")

        var updated = preferences
        updated.preferredPaymentToken = token

        await savePreferences(updated)
    }

    // MARK: - Helpers

    /// Get formatted amount in user's local currency
    func formatAmount(_ amount: Double) -> String {
        preferences.localCurrency.format(amount)
    }
}

// MARK: - SharedDataManager Extension

/// Helper for sharing data with iMessage extension
class SharedDataManager {
    static let shared = SharedDataManager()

    private let suiteName = "group.com.syndicatemike.Mimic"
    private var sharedDefaults: UserDefaults?

    private init() {
        sharedDefaults = UserDefaults(suiteName: suiteName)
    }

    // MARK: - Wallet Data (Read-Only in Extension)

    var walletAddress: String? {
        sharedDefaults?.string(forKey: "mimic.wallet.address")
    }

    var displayName: String? {
        sharedDefaults?.string(forKey: "mimic.user.displayName")
    }

    var preferredToken: String {
        sharedDefaults?.string(forKey: "mimic.user.preferredToken") ?? "SOL"
    }

    // MARK: - Main App Methods (Write)

    func updateWalletAddress(_ address: String) {
        sharedDefaults?.set(address, forKey: "mimic.wallet.address")
    }

    func updateDisplayName(_ name: String) {
        sharedDefaults?.set(name, forKey: "mimic.user.displayName")
    }

    func updatePreferredToken(_ token: String) {
        sharedDefaults?.set(token, forKey: "mimic.user.preferredToken")
    }
}
