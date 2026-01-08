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

// MARK: - Fiat Currency

enum FiatCurrency: String, Codable, CaseIterable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case cad = "CAD"
    case aud = "AUD"
    case chf = "CHF"
    case cny = "CNY"
    case inr = "INR"
    case mxn = "MXN"

    var id: String { rawValue }

    /// Display name for the currency
    var displayName: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .jpy: return "Japanese Yen"
        case .cad: return "Canadian Dollar"
        case .aud: return "Australian Dollar"
        case .chf: return "Swiss Franc"
        case .cny: return "Chinese Yuan"
        case .inr: return "Indian Rupee"
        case .mxn: return "Mexican Peso"
        }
    }

    /// Currency symbol
    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "¥"
        case .cad: return "CA$"
        case .aud: return "A$"
        case .chf: return "CHF"
        case .cny: return "¥"
        case .inr: return "₹"
        case .mxn: return "MX$"
        }
    }

    /// Format amount with currency
    func format(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = rawValue
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(symbol)\(amount)"
    }
}

/// User preferences for app settings
struct UserPreferences: Codable {
    // App settings
    var notificationsEnabled: Bool
    var theme: AppTheme

    // Payment preferences
    var localCurrency: FiatCurrency
    var preferredPaymentToken: String?

    var createdAt: Date
    var updatedAt: Date

    init(
        notificationsEnabled: Bool = false,
        theme: AppTheme = .system,
        localCurrency: FiatCurrency = .usd,
        preferredPaymentToken: String? = "SOL",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.theme = theme
        self.localCurrency = localCurrency
        self.preferredPaymentToken = preferredPaymentToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convert to Firestore-compatible dictionary
    func toDictionary() -> [String: Any] {
        return [
            "notificationsEnabled": notificationsEnabled,
            "theme": theme.rawValue,
            "localCurrency": localCurrency.rawValue,
            "preferredPaymentToken": preferredPaymentToken as Any,
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

        let localCurrency = (dictionary["localCurrency"] as? String)
            .flatMap { FiatCurrency(rawValue: $0) } ?? .usd

        let preferredPaymentToken = dictionary["preferredPaymentToken"] as? String

        return UserPreferences(
            notificationsEnabled: notificationsEnabled,
            theme: theme,
            localCurrency: localCurrency,
            preferredPaymentToken: preferredPaymentToken,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
