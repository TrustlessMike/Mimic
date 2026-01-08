import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "ThemeManager")

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
        logger.debug("Setting theme to: \(theme.rawValue)")
        currentTheme = theme
    }

    /// Apply the current theme to the app
    private func applyTheme() {
        switch currentTheme {
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .system:
            colorScheme = nil
        }
    }

    /// Save theme preference to UserDefaults
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
    }

    // MARK: - Theme Colors

    /// Get primary color for current theme (Mimic brand blue)
    /// Uses adaptive primary which automatically adjusts for dark/light mode
    var primaryColor: Color {
        BrandColors.adaptivePrimary
    }

    /// Get background color for current theme
    /// Uses system background which automatically adapts to color scheme
    var backgroundColor: Color {
        Color(UIColor.systemBackground)
    }

    /// Get secondary background color for current theme
    /// Uses system secondary background which automatically adapts to color scheme
    var secondaryBackgroundColor: Color {
        Color(UIColor.secondarySystemBackground)
    }
}

// MARK: - Haptic Manager (Shared)

/// Centralized manager for haptic feedback
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // MARK: - Feedback Generators
    
    /// Light tap feedback (for toggles, buttons)
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Notification feedback (success, error, warning)
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    /// Selection feedback (picker wheels, sliders)
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // MARK: - Convenience Methods
    
    /// Success vibration (e.g. completed transaction)
    func success() {
        notification(type: .success)
    }
    
    /// Error vibration (e.g. form validation failed)
    func error() {
        notification(type: .error)
    }
    
    /// Warning vibration
    func warning() {
        notification(type: .warning)
    }
    
    /// Light tap (e.g. tab change)
    func lightTap() {
        impact(style: .light)
    }
    
    /// Medium tap (e.g. button press)
    func mediumTap() {
        impact(style: .medium)
    }
    
    /// Heavy tap (e.g. major action)
    func heavyTap() {
        impact(style: .heavy)
    }
}
