import Foundation

/// App theme options
enum AppTheme: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"

    var displayName: String {
        return rawValue
    }
}

/// User preferences for app settings
struct UserPreferences: Codable {
    var notificationsEnabled: Bool
    var theme: AppTheme
    var createdAt: Date
    var updatedAt: Date

    init(
        notificationsEnabled: Bool = false,
        theme: AppTheme = .system,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.theme = theme
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convert to Firestore-compatible dictionary
    func toDictionary() -> [String: Any] {
        return [
            "notificationsEnabled": notificationsEnabled,
            "theme": theme.rawValue,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
    }

    /// Create from Firestore dictionary
    static func from(dictionary: [String: Any]) -> UserPreferences? {
        guard let notificationsEnabled = dictionary["notificationsEnabled"] as? Bool,
              let themeString = dictionary["theme"] as? String,
              let theme = AppTheme(rawValue: themeString),
              let createdAt = dictionary["createdAt"] as? Date,
              let updatedAt = dictionary["updatedAt"] as? Date else {
            return nil
        }

        return UserPreferences(
            notificationsEnabled: notificationsEnabled,
            theme: theme,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
