import SwiftUI

/// Leaderboard showing ranked smart money wallets we track
struct LeaderboardView: View {
    @StateObject private var predictionService = PredictionService.shared

    var body: some View {
        NavigationStack {
            Group {
                if predictionService.isLoadingWallets && predictionService.smartMoneyWallets.isEmpty {
                    loadingState
                } else if predictionService.smartMoneyWallets.isEmpty {
                    emptyState
                } else {
                    leaderboardList
                }
            }
            .navigationTitle("Leaderboard")
            .task {
                await predictionService.loadSmartMoneyWallets()
            }
            .refreshable {
                await predictionService.loadSmartMoneyWallets()
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading smart money...")
                .font(Typography.bodyMedium)
                .foregroundColor(SemanticColors.textSecondary)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "trophy")
                .font(.system(size: IconSize.xxl + 16))
                .foregroundColor(SemanticColors.textSecondary)

            VStack(spacing: Spacing.sm) {
                Text("No Data Yet")
                    .font(Typography.headlineMedium)
                    .fontWeight(.bold)
                    .foregroundColor(SemanticColors.textPrimary)

                Text("We're finding the best predictors on Jupiter. Check back soon!")
                    .font(Typography.bodyMedium)
                    .foregroundColor(SemanticColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            Spacer()
        }
    }

    // MARK: - Leaderboard List

    private var leaderboardList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header stats
                headerStats
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)

                // Ranked wallet list
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(Array(predictionService.smartMoneyWallets.enumerated()), id: \.element.id) { index, wallet in
                        LeaderboardRow(rank: index + 1, wallet: wallet)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Header Stats

    private var headerStats: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.lg) {
                LeaderboardStatCard(
                    title: "Wallets Tracked",
                    value: "\(predictionService.smartMoneyWallets.count)",
                    icon: "eye.fill",
                    color: BrandColors.primary
                )

                if let avgWinRate = averageWinRate {
                    LeaderboardStatCard(
                        title: "Avg Win Rate",
                        value: "\(Int(avgWinRate * 100))%",
                        icon: "chart.line.uptrend.xyaxis",
                        color: SemanticColors.success
                    )
                }
            }

            // Info banner
            HStack(spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(BrandColors.primary)
                Text("We track top prediction market traders so you don't have to")
                    .font(Typography.labelSmall)
                    .foregroundColor(SemanticColors.textSecondary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(BrandColors.primary.opacity(0.1))
            .cornerRadius(CornerRadius.sm)
        }
    }

    private var averageWinRate: Double? {
        let wallets = predictionService.smartMoneyWallets
        guard !wallets.isEmpty else { return nil }
        let total = wallets.reduce(0.0) { $0 + $1.stats.winRate }
        return total / Double(wallets.count)
    }
}

// MARK: - Stat Card

private struct LeaderboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(Typography.labelSmall)
                    .foregroundColor(color)
                Text(title)
                    .font(Typography.labelSmall)
                    .foregroundColor(SemanticColors.textSecondary)
            }

            Text(value)
                .font(Typography.headlineMedium)
                .fontWeight(.bold)
                .foregroundColor(SemanticColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(SemanticColors.surfaceDefault)
        .cornerRadius(CornerRadius.md)
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let wallet: SmartMoneyWallet

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Rank badge
            rankBadge

            // Avatar
            ZStack {
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 44, height: 44)

                Text(String((wallet.nickname ?? wallet.address).prefix(1)).uppercased())
                    .font(Typography.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundColor(SemanticColors.textInverse)
            }

            // Info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(wallet.nickname ?? shortenAddress(wallet.address))
                        .font(Typography.headlineSmall)
                        .foregroundColor(SemanticColors.textPrimary)

                    Image(systemName: "checkmark.seal.fill")
                        .font(Typography.labelSmall)
                        .foregroundColor(BrandColors.primary)
                }

                Text("\(wallet.stats.totalBets) bets")
                    .font(Typography.labelSmall)
                    .foregroundColor(SemanticColors.textTertiary)
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text("\(Int(wallet.stats.winRate * 100))%")
                        .font(Typography.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(wallet.stats.winRate >= 0.5 ? SemanticColors.success : SemanticColors.error)

                    Image(systemName: wallet.stats.winRate >= 0.5 ? "arrow.up.right" : "arrow.down.right")
                        .font(Typography.labelSmall)
                        .foregroundColor(wallet.stats.winRate >= 0.5 ? SemanticColors.success : SemanticColors.error)
                }

                Text(formatPnL(wallet.stats.totalPnl))
                    .font(Typography.labelSmall)
                    .foregroundColor(wallet.stats.totalPnl >= 0 ? SemanticColors.success : SemanticColors.error)
            }
        }
        .padding(Spacing.md)
        .background(SemanticColors.surfaceDefault)
        .cornerRadius(CornerRadius.md)
    }

    private var rankBadge: some View {
        ZStack {
            if rank <= 3 {
                Circle()
                    .fill(rankColor)
                    .frame(width: 28, height: 28)

                Text("\(rank)")
                    .font(Typography.labelMedium)
                    .fontWeight(.bold)
                    .foregroundColor(SemanticColors.textInverse)
            } else {
                Text("#\(rank)")
                    .font(Typography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(SemanticColors.textSecondary)
                    .frame(width: 28)
            }
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return SemanticColors.textSecondary
        }
    }

    private var avatarGradient: LinearGradient {
        let hash = wallet.address.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.7, brightness: 0.8),
                Color(hue: hue, saturation: 0.6, brightness: 0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func shortenAddress(_ address: String) -> String {
        guard address.count > 8 else { return address }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }

    private func formatPnL(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", value)) SOL"
    }
}

#Preview {
    LeaderboardView()
        .environmentObject(ThemeManager.shared)
}
