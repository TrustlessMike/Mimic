import SwiftUI

// MARK: - Spacing Scale

/// 4pt base unit spacing system for consistent layout rhythm
enum Spacing {
    /// 2pt - Micro adjustments
    static let xxs: CGFloat = 2
    /// 4pt - Icon padding, tight gaps
    static let xs: CGFloat = 4
    /// 8pt - Between related elements
    static let sm: CGFloat = 8
    /// 12pt - Standard element spacing
    static let md: CGFloat = 12
    /// 16pt - Component padding, section spacing
    static let lg: CGFloat = 16
    /// 24pt - Between major sections
    static let xl: CGFloat = 24
    /// 32pt - Large section gaps
    static let xxl: CGFloat = 32
    /// 48pt - Screen-level spacing
    static let xxxl: CGFloat = 48
}

// MARK: - Typography Scale

/// Semantic typography system for consistent text hierarchy
enum Typography {
    // Display - Hero numbers (balance totals, large amounts)
    static let displayLarge = Font.system(size: 40, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 32, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 28, weight: .semibold, design: .rounded)

    // Headlines - Section headers, card titles
    static let headlineLarge = Font.system(size: 24, weight: .bold)
    static let headlineMedium = Font.system(size: 20, weight: .semibold)
    static let headlineSmall = Font.system(size: 17, weight: .semibold)

    // Body - Primary content text
    static let bodyLarge = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)

    // Labels - UI labels, buttons, badges
    static let labelLarge = Font.system(size: 15, weight: .medium)
    static let labelMedium = Font.system(size: 13, weight: .medium)
    static let labelSmall = Font.system(size: 11, weight: .medium)

    // Monospace - Addresses, amounts, code
    static let monoLarge = Font.system(size: 17, weight: .medium, design: .monospaced)
    static let monoMedium = Font.system(size: 15, weight: .medium, design: .monospaced)
    static let monoSmall = Font.system(size: 13, weight: .regular, design: .monospaced)
}

// MARK: - Corner Radius Scale

/// Consistent corner radius values for UI elements
enum CornerRadius {
    /// 4pt - Small badges, chips
    static let xs: CGFloat = 4
    /// 8pt - Buttons, input fields
    static let sm: CGFloat = 8
    /// 12pt - Standard cards, modals
    static let md: CGFloat = 12
    /// 16pt - Feature cards
    static let lg: CGFloat = 16
    /// 20pt - Hero cards (balance card)
    static let xl: CGFloat = 20
    /// 9999pt - Fully rounded pills
    static let full: CGFloat = 9999
}

// MARK: - Elevation System

/// Shadow/elevation levels for visual depth hierarchy
enum Elevation {
    /// No elevation - flat elements
    static let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)

    /// Subtle lift - cards, list items
    static let low = ShadowStyle(
        color: Color.black.opacity(0.04),
        radius: 4,
        x: 0,
        y: 2
    )

    /// Medium elevation - active cards, hover states
    static let medium = ShadowStyle(
        color: Color.black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 4
    )

    /// High elevation - floating elements, modals
    static let high = ShadowStyle(
        color: Color.black.opacity(0.12),
        radius: 16,
        x: 0,
        y: 8
    )

    /// Brand glow shadow for primary CTAs
    static func brand(_ color: Color = BrandColors.primary) -> ShadowStyle {
        ShadowStyle(
            color: color.opacity(0.35),
            radius: 12,
            x: 0,
            y: 6
        )
    }
}

/// Shadow style container for elevation system
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Semantic Colors

/// Extended color palette with semantic meaning
enum SemanticColors {
    // MARK: Background Hierarchy
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)

    // MARK: Surface Colors (for cards)
    static let surfaceDefault = Color(UIColor.secondarySystemBackground)
    static let surfaceSubtle = Color(UIColor.tertiarySystemBackground)
    static let surfaceElevated = Color(UIColor.systemBackground)

    // MARK: Text Hierarchy
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)
    static let textInverse = Color.white
    static let textOnGradient = Color.white

    // MARK: Status Colors with Light Backgrounds
    static let success = BrandColors.success
    static let successLight = BrandColors.success.opacity(0.15)

    static let warning = BrandColors.warning
    static let warningLight = BrandColors.warning.opacity(0.15)

    static let error = BrandColors.error
    static let errorLight = BrandColors.error.opacity(0.15)

    static let info = BrandColors.blue
    static let infoLight = BrandColors.blue.opacity(0.15)

    // MARK: Interactive States
    static let interactiveDefault = BrandColors.primary
    static let interactivePressed = BrandColors.primary.opacity(0.8)
    static let interactiveDisabled = Color(UIColor.systemGray3)

    // MARK: Dividers & Borders
    static let divider = Color(UIColor.separator)
    static let border = Color(UIColor.systemGray4)
    static let borderFocused = BrandColors.primary
}

// MARK: - Animation Constants

/// Consistent animation timings
enum AnimationTiming {
    /// Quick interactions (button press)
    static let fast: Double = 0.15
    /// Standard transitions
    static let normal: Double = 0.25
    /// Slow, smooth animations
    static let slow: Double = 0.35

    /// Spring animation for interactive elements
    static let springResponse: Double = 0.3
    static let springDamping: Double = 0.7
}

// MARK: - Icon Sizes

/// Standard icon sizes
enum IconSize {
    /// 16pt - Inline icons
    static let sm: CGFloat = 16
    /// 20pt - Button icons
    static let md: CGFloat = 20
    /// 24pt - Standard icons
    static let lg: CGFloat = 24
    /// 32pt - Feature icons
    static let xl: CGFloat = 32
    /// 48pt - Empty state icons
    static let xxl: CGFloat = 48
}
