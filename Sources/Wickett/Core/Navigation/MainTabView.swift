import SwiftUI

struct MainTabView: View {
    let onSignOut: () async -> Void

    @EnvironmentObject var authCoordinator: AuthCoordinator

    private var user: User? { authCoordinator.currentUser }

    @State private var selectedTab: Tab = .feed
    @State private var showAddWallet = false
    @State private var showAddFundsView = false

    // Mimic: Wallet tracking and copy trading app

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Content
            Group {
                switch selectedTab {
                case .feed:
                    FeedView()
                case .discover:
                    // Placeholder for discover/leaderboards
                    DiscoverPlaceholderView()
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
                    showAddWallet = true
                }
            )
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showAddWallet) {
            AddWalletView()
        }
        .sheet(isPresented: $showAddFundsView) {
            CoinbaseOnrampView()
        }
    }
}

// MARK: - Tab Enum (Mimic)

enum Tab: String, CaseIterable {
    case feed
    case discover
    case portfolio
    case settings
}

// MARK: - Discover Placeholder

struct DiscoverPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    Text("Discover Traders")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Find top performing wallets to track")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Coming Soon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)

                Spacer()
            }
            .navigationTitle("Discover")
        }
    }
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
