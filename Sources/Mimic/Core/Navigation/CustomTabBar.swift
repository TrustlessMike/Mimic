import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    let onCenterTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Subtle top border
            Rectangle()
                .fill(SemanticColors.divider.opacity(0.3))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                // Feed - Smart money bets
                TabBarButton(
                    icon: "chart.line.uptrend.xyaxis",
                    selectedIcon: "chart.line.uptrend.xyaxis",
                    title: "Feed",
                    tab: .feed,
                    selectedTab: $selectedTab
                )

                // Leaderboard - Ranked smart money wallets
                TabBarButton(
                    icon: "trophy",
                    selectedIcon: "trophy.fill",
                    title: "Leaderboard",
                    tab: .leaderboard,
                    selectedTab: $selectedTab
                )

                // Center Action Button (Copy Trading)
                Button(action: onCenterTap) {
                    ZStack {
                        Circle()
                            .fill(BrandColors.primaryGradient)
                            .frame(width: 56, height: 56)
                            .shadow(
                                color: Elevation.brand().color,
                                radius: Elevation.brand().radius,
                                x: 0,
                                y: Elevation.brand().y
                            )

                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: IconSize.lg, weight: .semibold))
                            .foregroundColor(SemanticColors.textInverse)
                    }
                    .frame(width: 70)
                }
                .offset(y: -Spacing.lg)

                // Portfolio - Your wallet
                TabBarButton(
                    icon: "wallet.pass",
                    selectedIcon: "wallet.pass.fill",
                    title: "Wallet",
                    tab: .portfolio,
                    selectedTab: $selectedTab
                )

                // Settings
                TabBarButton(
                    icon: "gearshape",
                    selectedIcon: "gearshape.fill",
                    title: "Settings",
                    tab: .settings,
                    selectedTab: $selectedTab
                )
            }
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
            .background(
                SemanticColors.backgroundPrimary
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4)
                    .ignoresSafeArea()
            )
        }
        .background(Color.clear)
    }

    private func getSafeAreaBottom() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }
}

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let title: String
    let tab: Tab
    @Binding var selectedTab: Tab

    var isSelected: Bool {
        selectedTab == tab
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: AnimationTiming.springResponse, dampingFraction: AnimationTiming.springDamping)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: IconSize.lg))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .foregroundColor(isSelected ? BrandColors.primary : SemanticColors.textSecondary)

                Text(title)
                    .font(Typography.labelSmall)
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundColor(isSelected ? BrandColors.primary : SemanticColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    ZStack {
        Color.blue
        VStack {
            Spacer()
            CustomTabBar(selectedTab: .constant(.feed), onCenterTap: {})
        }
    }
}
