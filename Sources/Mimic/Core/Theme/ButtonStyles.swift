import SwiftUI

// MARK: - Primary Button Style

/// Primary CTA button with gradient background and brand shadow
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelLarge)
            .fontWeight(.semibold)
            .foregroundColor(SemanticColors.textInverse)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(
                isEnabled
                    ? BrandColors.primaryGradient
                    : LinearGradient(
                        colors: [SemanticColors.interactiveDisabled],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .cornerRadius(CornerRadius.sm)
            .shadow(
                color: isEnabled ? Elevation.brand().color : .clear,
                radius: configuration.isPressed ? 6 : Elevation.brand().radius,
                x: 0,
                y: configuration.isPressed ? 3 : Elevation.brand().y
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AnimationTiming.fast), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

/// Secondary button with tinted background
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelLarge)
            .fontWeight(.semibold)
            .foregroundColor(isEnabled ? BrandColors.primary : SemanticColors.interactiveDisabled)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(
                isEnabled
                    ? BrandColors.primary.opacity(0.12)
                    : SemanticColors.interactiveDisabled.opacity(0.12)
            )
            .cornerRadius(CornerRadius.sm)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AnimationTiming.fast), value: configuration.isPressed)
    }
}

// MARK: - Ghost Button Style

/// Text-only button for tertiary actions
struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelMedium)
            .foregroundColor(isEnabled ? BrandColors.primary : SemanticColors.interactiveDisabled)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeOut(duration: AnimationTiming.fast), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style

/// Red button for destructive actions
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelLarge)
            .fontWeight(.semibold)
            .foregroundColor(SemanticColors.textInverse)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(isEnabled ? SemanticColors.error : SemanticColors.interactiveDisabled)
            .cornerRadius(CornerRadius.sm)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AnimationTiming.fast), value: configuration.isPressed)
    }
}

// MARK: - Chip Button Style

/// Filter chip button with selected/unselected states
struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    init(isSelected: Bool = false) {
        self.isSelected = isSelected
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelMedium)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? SemanticColors.textInverse : SemanticColors.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected
                    ? AnyView(BrandColors.primaryGradient)
                    : AnyView(SemanticColors.surfaceDefault)
            )
            .cornerRadius(CornerRadius.full)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                .spring(response: AnimationTiming.springResponse, dampingFraction: AnimationTiming.springDamping),
                value: configuration.isPressed
            )
    }
}

// MARK: - Icon Button Style

/// Circular icon button for toolbars and tab bars
struct IconButtonStyle: ButtonStyle {
    let size: CGFloat
    let isSelected: Bool

    init(size: CGFloat = 48, isSelected: Bool = false) {
        self.size = size
        self.isSelected = isSelected
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                isSelected
                    ? BrandColors.primary.opacity(0.12)
                    : Color.clear
            )
            .cornerRadius(CornerRadius.sm)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: AnimationTiming.fast), value: configuration.isPressed)
    }
}

// MARK: - Action Button Style

/// Circular action button with colored background (for quick actions)
struct ActionButtonStyle: ButtonStyle {
    let color: Color
    let size: CGFloat

    init(color: Color, size: CGFloat = 50) {
        self.color = color
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(color.opacity(0.12))
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                .spring(response: AnimationTiming.springResponse, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

// MARK: - Scale Button Style

/// Simple scale effect on press (existing style, kept for compatibility)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                .spring(response: AnimationTiming.springResponse, dampingFraction: AnimationTiming.springDamping),
                value: configuration.isPressed
            )
    }
}

// MARK: - Card Button Style

/// Button style for tappable cards
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: AnimationTiming.fast), value: configuration.isPressed)
    }
}

// MARK: - Button Style Extensions

extension View {
    /// Apply primary button styling
    func primaryButtonStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }

    /// Apply secondary button styling
    func secondaryButtonStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }

    /// Apply ghost button styling
    func ghostButtonStyle() -> some View {
        self.buttonStyle(GhostButtonStyle())
    }

    /// Apply chip button styling
    func chipButtonStyle(isSelected: Bool) -> some View {
        self.buttonStyle(ChipButtonStyle(isSelected: isSelected))
    }
}
