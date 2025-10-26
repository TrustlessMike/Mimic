import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Wickett", category: "ThemeManager")

/// Manages app theme and appearance
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet {
            saveTheme()
            applyTheme()
        }
    }

    @Published var colorScheme: ColorScheme?

    private let userDefaults = UserDefaults.standard
    private let themeKey = "appTheme"

    private init() {
        // Load saved theme or default to system
        if let savedTheme = userDefaults.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .system
        }

        applyTheme()
    }

    // MARK: - Theme Management

    /// Set the app theme
    func setTheme(_ theme: AppTheme) {
        logger.info("🎨 Setting theme to: \(theme.rawValue)")
        currentTheme = theme
    }

    /// Apply the current theme to the app
    private func applyTheme() {
        switch currentTheme {
        case .light:
            colorScheme = .light
            logger.info("☀️ Applied light theme")
        case .dark:
            colorScheme = .dark
            logger.info("🌙 Applied dark theme")
        case .system:
            colorScheme = nil
            logger.info("⚙️ Applied system theme")
        }
    }

    /// Save theme preference to UserDefaults
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
        logger.info("💾 Theme saved: \(self.currentTheme.rawValue)")
    }

    // MARK: - Theme Colors

    /// Get primary color for current theme
    var primaryColor: Color {
        switch currentTheme {
        case .light:
            return Color.blue
        case .dark:
            return Color.cyan
        case .system:
            return Color.accentColor
        }
    }

    /// Get background color for current theme
    var backgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(UIColor.systemBackground)
        case .dark:
            return Color(UIColor.systemBackground)
        case .system:
            return Color(UIColor.systemBackground)
        }
    }

    /// Get secondary background color for current theme
    var secondaryBackgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(UIColor.secondarySystemBackground)
        case .dark:
            return Color(UIColor.secondarySystemBackground)
        case .system:
            return Color(UIColor.secondarySystemBackground)
        }
    }
}
