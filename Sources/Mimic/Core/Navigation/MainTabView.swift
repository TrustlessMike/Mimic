import SwiftUI

struct MainTabView: View {
    let onSignOut: () async -> Void

    @EnvironmentObject var authCoordinator: AuthCoordinator

    private var user: User? { authCoordinator.currentUser }

    @State private var selectedTab: Tab = .feed
    @State private var showingCopyTrading = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Content
            Group {
                switch selectedTab {
                case .feed:
                    PredictionFeedView()
                case .leaderboard:
                    LeaderboardView()
                case .portfolio:
                    PositionsView()
                case .settings:
                    if let user = user {
                        SettingsView(
                            user: user,
                            onDismiss: {},
                            onSignOut: onSignOut
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // MARK: - Custom Tab Bar
            CustomTabBar(
                selectedTab: $selectedTab,
                onCenterTap: {
                    showingCopyTrading = true
                }
            )
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showingCopyTrading) {
            TrackedWalletsView()
        }
    }
}

// MARK: - Tab Enum (Mimic App)

enum Tab: String, CaseIterable {
    case feed       // Smart money bets feed
    case leaderboard // Ranked smart money wallets
    case portfolio  // Your own wallet
    case settings   // App settings
}

#Preview {
    MainTabView(
        onSignOut: {}
    )
    .environmentObject(AuthCoordinator.shared)
    .environmentObject(OnboardingManager.shared)
    .environmentObject(ThemeManager.shared)
    .environmentObject(NotificationManager.shared)
}
