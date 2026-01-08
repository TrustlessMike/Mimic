import SwiftUI

struct MainTabView: View {
    let onSignOut: () async -> Void

    @EnvironmentObject var authCoordinator: AuthCoordinator

    private var user: User? { authCoordinator.currentUser }

    @State private var selectedTab: Tab = .feed

    // Jupiter Prediction Markets URL
    private let jupiterPredictionURL = URL(string: "https://jup.ag/perps/SOL-PERP")!

    // Mimic - Track smart money on Jupiter Prediction Markets

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
                    if let user = user {
                        WalletView(user: user)
                    }
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
                    // Open Jupiter Prediction Markets
                    UIApplication.shared.open(jupiterPredictionURL)
                }
            )
        }
        .ignoresSafeArea(.keyboard)
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
