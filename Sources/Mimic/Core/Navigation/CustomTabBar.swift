import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    let onCenterTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Subtle top border (like X)
            Rectangle()
                .fill(Color.primary.opacity(0.1))
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

                // Positions - Your active bets
                TabBarButton(
                    icon: "list.bullet.clipboard",
                    selectedIcon: "list.bullet.clipboard.fill",
                    title: "Positions",
                    tab: .portfolio,
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

                // Leaderboard - Ranked smart money wallets
                TabBarButton(
                    icon: "trophy",
                    selectedIcon: "trophy.fill",
                    title: "Leaderboard",
                    tab: .leaderboard,
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
        }
        .background(.regularMaterial)
        .ignoresSafeArea(.container, edges: .bottom)
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
