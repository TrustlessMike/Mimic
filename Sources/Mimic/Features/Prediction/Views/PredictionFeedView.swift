import SwiftUI

/// Main feed view showing bets from curated smart money wallets
struct PredictionFeedView: View {
    @StateObject private var predictionService = PredictionService.shared
    @State private var selectedFilter: BetFeedFilter = .all
    @State private var showSmartMoneyList = false
    @State private var isLoadingMore = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Smart Money Stats Bar
                smartMoneyBar
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)

                // Filter Chips
                filterChips
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)

                // Content
                if predictionService.betFeed.isEmpty && predictionService.isLoadingFeed {
                    loadingState
                } else if predictionService.betFeed.isEmpty {
                    noBetsState
                } else {
                    betFeedList
                }
            }
            .navigationTitle("Smart Money")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSmartMoneyList = true }) {
                        Image(systemName: "person.2.fill")
                            .font(Typography.headlineSmall)
                            .foregroundColor(BrandColors.primary)
                    }
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                await refreshData()
            }
            .sheet(isPresented: $showSmartMoneyList) {
                SmartMoneyListView()
            }
        }
    }

    // MARK: - Smart Money Stats Bar

    private var smartMoneyBar: some View {
        HStack(spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Tracking")
                    .font(Typography.labelSmall)
                    .foregroundColor(SemanticColors.textSecondary)
                Text("\(predictionService.smartMoneyWallets.count) Wallets")
                    .font(Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(SemanticColors.textPrimary)
            }

            Spacer()

            if let topWallet = predictionService.smartMoneyWallets.first {
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("Top Performer")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                    HStack(spacing: Spacing.xs) {
                        Text(topWallet.nickname ?? shortenAddress(topWallet.address))
                            .font(Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(SemanticColors.textPrimary)
                        Text("\(Int(topWallet.stats.winRate * 100))%")
                            .font(Typography.labelSmall)
                            .foregroundColor(SemanticColors.success)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(SemanticColors.surfaceDefault)
        .cornerRadius(CornerRadius.md)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(BetFeedFilter.allCases, id: \.self) { filter in
                    BetFilterChip(
                        title: filter.displayName,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        Task {
                            await predictionService.refreshFeed(filter: filter)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bet Feed List

    private var betFeedList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(predictionService.betFeed) { bet in
                    BetCardView(bet: bet)
                        .onAppear {
                            // Load more when reaching end (with debounce to prevent duplicate calls)
                            if bet.id == predictionService.betFeed.last?.id && !isLoadingMore {
                                Task {
                                    isLoadingMore = true
                                    defer { isLoadingMore = false }
                                    await predictionService.loadMoreBets(filter: selectedFilter)
                                }
                            }
                        }
                }

                if predictionService.isLoadingFeed {
                    ProgressView()
                        .padding(Spacing.lg)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, 100) // Space for tab bar
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading smart money bets...")
                .font(Typography.bodyMedium)
                .foregroundColor(SemanticColors.textSecondary)
            Spacer()
        }
    }

    private var noBetsState: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: IconSize.xxl + 16))
                .foregroundColor(SemanticColors.textSecondary)

            VStack(spacing: Spacing.sm) {
                Text("No Bets Yet")
                    .font(Typography.headlineMedium)
                    .fontWeight(.bold)
                    .foregroundColor(SemanticColors.textPrimary)

                Text("Smart money wallets haven't placed any bets recently. Check back soon!")
                    .font(Typography.bodyMedium)
                    .foregroundColor(SemanticColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            // Show smart money wallet count
            if !predictionService.smartMoneyWallets.isEmpty {
                Text("Monitoring \(predictionService.smartMoneyWallets.count) smart money wallet\(predictionService.smartMoneyWallets.count == 1 ? "" : "s")")
                    .font(Typography.labelSmall)
                    .foregroundColor(SemanticColors.textSecondary)
                    .padding(.top, Spacing.sm)
            }

            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        await predictionService.loadSmartMoneyWallets()
        await predictionService.loadBetFeed(filter: selectedFilter, refresh: true)
        predictionService.startFeedListener()
    }

    private func refreshData() async {
        await predictionService.loadSmartMoneyWallets()
        await predictionService.refreshFeed(filter: selectedFilter)
    }

    private func shortenAddress(_ address: String) -> String {
        guard address.count > 8 else { return address }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}

// MARK: - Smart Money List View

struct SmartMoneyListView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var predictionService = PredictionService.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(predictionService.smartMoneyWallets) { wallet in
                    SmartMoneyWalletRow(wallet: wallet)
                }
            }
            .navigationTitle("Smart Money Wallets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SmartMoneyWalletRow: View {
    let wallet: SmartMoneyWallet

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            Circle()
                .fill(avatarGradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String((wallet.nickname ?? wallet.address).prefix(1)).uppercased())
                        .font(Typography.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(SemanticColors.textInverse)
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(wallet.nickname ?? shortenAddress(wallet.address))
                    .font(Typography.headlineSmall)
                    .foregroundColor(SemanticColors.textPrimary)

                if let notes = wallet.notes {
                    Text(notes)
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text("\(Int(wallet.stats.winRate * 100))%")
                        .font(Typography.headlineSmall)
                        .foregroundColor(SemanticColors.success)
                    Text("Win")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                }

                Text("\(wallet.stats.totalBets) bets")
                    .font(Typography.labelSmall)
                    .foregroundColor(SemanticColors.textSecondary)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var avatarGradient: LinearGradient {
        let hash = wallet.address.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.7, brightness: 0.8),
                Color(hue: hue, saturation: 0.6, brightness: 0.6),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func shortenAddress(_ address: String) -> String {
        guard address.count > 8 else { return address }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}

// MARK: - Bet Filter Chip

struct BetFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(Typography.labelSmall)
                Text(title)
                    .font(Typography.labelMedium)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? SemanticColors.textInverse : SemanticColors.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected
                    ? AnyView(BrandColors.primaryGradient)
                    : AnyView(SemanticColors.surfaceDefault)
            )
            .cornerRadius(CornerRadius.full)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    PredictionFeedView()
        .environmentObject(ThemeManager.shared)
}
