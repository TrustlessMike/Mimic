import SwiftUI

// MARK: - Custom Tab Bar (TikTok Style)

struct CustomTabBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        HStack(spacing: 0) {
            // Home Tab
            TabBarButton(
                icon: "house.fill",
                title: "Home",
                isSelected: selectedTab == .home,
                action: {
                    selectedTab = .home
                }
            )

            // Activity Tab
            TabBarButton(
                icon: "list.bullet.rectangle",
                title: "Activity",
                isSelected: selectedTab == .activity,
                action: {
                    selectedTab = .activity
                }
            )

            // Wallet Tab
            TabBarButton(
                icon: "wallet.pass.fill",
                title: "Wallet",
                isSelected: selectedTab == .wallet,
                action: {
                    selectedTab = .wallet
                }
            )

            // Settings Tab
            TabBarButton(
                icon: "gearshape.fill",
                title: "Settings",
                isSelected: selectedTab == .settings,
                action: {
                    selectedTab = .settings
                }
            )
        }
        .frame(height: 50)
        .padding(.bottom, getSafeAreaBottom())
        .background(
            // Blur effect background
            .ultraThinMaterial
        )
    }

    // Get safe area bottom inset
    private func getSafeAreaBottom() -> CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }.first

        return keyWindow?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .gray)

                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    CustomTabBar(selectedTab: .constant(.home))
}
