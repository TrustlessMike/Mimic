import SwiftUI

struct MainTabView: View {
    let user: User
    let onSignOut: () async -> Void

    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            EnhancedHomeView(
                user: user,
                onSettings: {
                    selectedTab = .settings
                },
                onSignOut: onSignOut
            )
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(Tab.home)

            // Activity Tab
            ActivityView(user: user)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .tabItem {
                    Label("Activity", systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.activity)

            // Wallet Tab
            WalletView(user: user)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .tabItem {
                    Label("Wallet", systemImage: "wallet.pass.fill")
                }
                .tag(Tab.wallet)

            // Settings Tab
            SettingsView(
                user: user,
                onDismiss: {
                    // No-op since we're in a tab, not a sheet
                },
                onSignOut: onSignOut
            )
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
        }
        .tint(.blue)
    }
}

// MARK: - Tab Enum

enum Tab {
    case home
    case activity
    case wallet
    case settings
}

#Preview {
    MainTabView(
        user: User(
            id: "test",
            email: "test@example.com",
            name: "Test User",
            walletAddress: "ABC123XYZ789ABC123XYZ789"
        ),
        onSignOut: {}
    )
    .environmentObject(OnboardingManager.shared)
    .environmentObject(ThemeManager.shared)
    .environmentObject(NotificationManager.shared)
}
