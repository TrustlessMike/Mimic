import SwiftUI

// MARK: - Card Modifier

/// Standard card styling with configurable elevation and padding
struct CardModifier: ViewModifier {
    let elevation: ShadowStyle
    let cornerRadius: CGFloat
    let padding: CGFloat
    let backgroundColor: Color

    init(
        elevation: ShadowStyle = Elevation.low,
        cornerRadius: CGFloat = CornerRadius.md,
        padding: CGFloat = Spacing.lg,
        backgroundColor: Color = SemanticColors.surfaceDefault
    ) {
        self.elevation = elevation
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.backgroundColor = backgroundColor
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: elevation.color,
                radius: elevation.radius,
                x: elevation.x,
                y: elevation.y
            )
    }
}

// MARK: - Hero Card Modifier

/// Hero card with gradient background and brand shadow (for balance cards)
struct HeroCardModifier: ViewModifier {
    let padding: CGFloat

    init(padding: CGFloat = Spacing.xl) {
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrandColors.primaryGradient)
            .cornerRadius(CornerRadius.xl)
            .shadow(
                color: Elevation.brand().color,
                radius: Elevation.brand().radius,
                x: 0,
                y: Elevation.brand().y
            )
    }
}

// MARK: - Status Badge Modifier

/// Status badge styling for different states
struct StatusBadgeModifier: ViewModifier {
    let status: StatusType

    enum StatusType {
        case success
        case warning
        case error
        case info
        case neutral
        case custom(foreground: Color, background: Color)

        var foregroundColor: Color {
            switch self {
            case .success: return SemanticColors.success
            case .warning: return SemanticColors.warning
            case .error: return SemanticColors.error
            case .info: return SemanticColors.info
            case .neutral: return SemanticColors.textSecondary
            case .custom(let foreground, _): return foreground
            }
        }

        var backgroundColor: Color {
            switch self {
            case .success: return SemanticColors.successLight
            case .warning: return SemanticColors.warningLight
            case .error: return SemanticColors.errorLight
            case .info: return SemanticColors.infoLight
            case .neutral: return SemanticColors.surfaceSubtle
            case .custom(_, let background): return background
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .font(Typography.labelSmall)
            .fontWeight(.bold)
            .foregroundColor(status.foregroundColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(status.backgroundColor)
            .cornerRadius(CornerRadius.xs)
    }
}

// MARK: - Direction Badge Modifier

/// Badge for YES/NO direction indicators
struct DirectionBadgeModifier: ViewModifier {
    let isYes: Bool

    var foregroundColor: Color {
        isYes ? SemanticColors.success : SemanticColors.error
    }

    var backgroundColor: Color {
        isYes ? SemanticColors.successLight : SemanticColors.errorLight
    }

    func body(content: Content) -> some View {
        content
            .font(Typography.labelSmall)
            .fontWeight(.bold)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(backgroundColor)
            .cornerRadius(CornerRadius.xs + 2)
    }
}

// MARK: - Surface Modifier

/// Apply surface background styling
struct SurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat

    init(cornerRadius: CGFloat = CornerRadius.sm, padding: CGFloat = Spacing.md) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, padding)
            .background(SemanticColors.surfaceDefault)
            .cornerRadius(cornerRadius)
    }
}

// MARK: - Shimmer Modifier (Enhanced)

/// Enhanced shimmer effect for loading states
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard card styling
    func card(
        elevation: ShadowStyle = Elevation.low,
        cornerRadius: CGFloat = CornerRadius.md,
        padding: CGFloat = Spacing.lg
    ) -> some View {
        self.modifier(CardModifier(
            elevation: elevation,
            cornerRadius: cornerRadius,
            padding: padding
        ))
    }

    /// Apply hero card styling with gradient and brand shadow
    func heroCard(padding: CGFloat = Spacing.xl) -> some View {
        self.modifier(HeroCardModifier(padding: padding))
    }

    /// Apply status badge styling
    func statusBadge(_ status: StatusBadgeModifier.StatusType) -> some View {
        self.modifier(StatusBadgeModifier(status: status))
    }

    /// Apply direction badge styling (YES/NO)
    func directionBadge(isYes: Bool) -> some View {
        self.modifier(DirectionBadgeModifier(isYes: isYes))
    }

    /// Apply surface background styling
    func surface(cornerRadius: CGFloat = CornerRadius.sm, padding: CGFloat = Spacing.md) -> some View {
        self.modifier(SurfaceModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// Apply shimmer loading effect
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }

    /// Apply standard shadow based on elevation
    func elevation(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}

// MARK: - Skeleton Shapes

/// Standard skeleton shape for loading states
struct SkeletonShape: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = CornerRadius.sm) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(SemanticColors.surfaceSubtle)
            .frame(width: width, height: height)
            .shimmer()
    }
}
