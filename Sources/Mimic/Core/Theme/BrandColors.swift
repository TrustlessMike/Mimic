import SwiftUI

/// Mimic brand color palette
enum BrandColors {
    // MARK: - Primary Brand Colors

    /// Meta Azure Blue #0082FB (0, 130, 251)
    /// Main brand color for primary actions, highlights, and brand identity
    static let blue = Color(red: 0/255, green: 130/255, blue: 251/255)

    /// Alias for the primary brand blue
    static let metaAzure = blue

    /// Pure white for text and accents
    static let white = Color.white

    /// Reflection color - white at 40% opacity for the "back mirror" effect
    static let reflection = Color.white.opacity(0.4)

    /// Alias for primary color (uses Meta Azure blue)
    static let primary = blue

    // MARK: - Semantic Colors

    /// Success color (green) - for positive actions and confirmations
    static let success = Color(red: 0.20, green: 0.78, blue: 0.35)

    /// Warning color (amber) - for cautionary messages
    static let warning = Color(red: 1.00, green: 0.76, blue: 0.03)

    /// Error color (red) - for errors and destructive actions
    static let error = Color(red: 0.96, green: 0.26, blue: 0.21)

    // MARK: - Gradient

    /// Primary brand gradient (blue to light blue) for cards and special UI elements
    static let primaryGradient: LinearGradient = LinearGradient(
        colors: [blue, blue.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Mirror effect gradient (blue to reflection) for logo-style effects
    static let mirrorGradient: LinearGradient = LinearGradient(
        colors: [blue, reflection],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Helper Methods

    /// Get the appropriate brand color based on color scheme
    static func adaptive(light: Color, dark: Color) -> Color {
        // SwiftUI will automatically handle this based on environment
        return Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// Primary brand color that adapts to dark mode
    /// Uses lighter blue in dark mode for better contrast
    static var adaptivePrimary: Color {
        adaptive(light: blue, dark: blue.opacity(0.9))
    }
}
