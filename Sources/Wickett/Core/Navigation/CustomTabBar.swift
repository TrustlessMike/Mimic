import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    let onCenterTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left Tabs
                TabBarButton(
                    icon: "list.bullet.rectangle",
                    selectedIcon: "list.bullet.rectangle.fill",
                    title: "Feed",
                    tab: .feed,
                    selectedTab: $selectedTab
                )

                TabBarButton(
                    icon: "sparkle.magnifyingglass",
                    selectedIcon: "sparkle.magnifyingglass",
                    title: "Discover",
                    tab: .discover,
                    selectedTab: $selectedTab
                )

                // Center Action Button (Add Wallet)
                Button(action: onCenterTap) {
                    ZStack {
                        Circle()
                            .fill(BrandColors.primaryGradient)
                            .frame(width: 48, height: 48)
                            .shadow(color: BrandColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)

                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 60)
                }
                .offset(y: -12)

                // Right Tabs
                TabBarButton(
                    icon: "chart.pie",
                    selectedIcon: "chart.pie.fill",
                    title: "Portfolio",
                    tab: .portfolio,
                    selectedTab: $selectedTab
                )

                TabBarButton(
                    icon: "gearshape",
                    selectedIcon: "gearshape.fill",
                    title: "Settings",
                    tab: .settings,
                    selectedTab: $selectedTab
                )
            }
            .padding(.top, 8)
            .background(
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground).opacity(0.0),
                        Color(UIColor.systemBackground).opacity(0.9),
                        Color(UIColor.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 24))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .foregroundColor(isSelected ? BrandColors.primary : .secondary)

                Text(title)
                    .font(.caption2)
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundColor(isSelected ? BrandColors.primary : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
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
