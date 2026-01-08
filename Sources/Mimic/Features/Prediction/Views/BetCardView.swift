import SwiftUI

/// Card displaying a single prediction bet from a tracked wallet
struct BetCardView: View {
    let bet: PredictionBet

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header: Wallet + Time
            HStack {
                // Wallet avatar
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(bet.displayName.prefix(1)).uppercased())
                            .font(Typography.labelMedium)
                            .fontWeight(.bold)
                            .foregroundColor(SemanticColors.textInverse)
                    )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(bet.displayName)
                        .font(Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(SemanticColors.textPrimary)

                    Text(bet.shortenedAddress)
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                }

                Spacer()

                // Timestamp
                Text(timeAgo(from: bet.timestamp))
                    .font(Typography.labelSmall)
                    .foregroundColor(SemanticColors.textSecondary)
            }

            // Bet Direction + Status
            HStack(spacing: Spacing.md) {
                // Direction badge (YES/NO)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: bet.direction == .yes ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(bet.direction.displayName)
                }
                .directionBadge(isYes: bet.direction == .yes)

                // Price
                Text("@ \(String(format: "%.0f", bet.avgPrice * 100))¢")
                    .font(Typography.labelSmall)
                    .fontWeight(.medium)
                    .foregroundColor(SemanticColors.textSecondary)

                Spacer()

                // Status badge
                statusBadge
            }

            // Market title
            if let title = bet.marketTitle {
                Text(title)
                    .font(Typography.bodyMedium)
                    .foregroundColor(SemanticColors.textPrimary)
                    .lineLimit(2)
                    .padding(.vertical, Spacing.xs)
            }

            // Bet amounts
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(bet.formattedAmount)
                        .font(Typography.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(SemanticColors.textPrimary)

                    Text("Bet Amount")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text(String(format: "%.1f", bet.shares))
                        .font(Typography.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(SemanticColors.textPrimary)

                    Text("Shares")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                }

                if let pnl = bet.pnl, bet.status != .open {
                    Spacer()

                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text(formatPnl(pnl))
                            .font(Typography.headlineSmall)
                            .fontWeight(.bold)
                            .foregroundColor(pnl >= 0 ? SemanticColors.success : SemanticColors.error)

                        Text("P&L")
                            .font(Typography.labelSmall)
                            .foregroundColor(SemanticColors.textSecondary)
                    }
                }
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .background(SemanticColors.surfaceDefault)
            .cornerRadius(CornerRadius.sm)

            // Action row
            HStack {
                // View on Explorer
                Button(action: {
                    if let url = bet.explorerURL {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.up.right.square")
                        Text("View Tx")
                    }
                    .font(Typography.labelSmall)
                    .foregroundColor(SemanticColors.textSecondary)
                }

                Spacer()

                // Category if available
                if let category = bet.marketCategory {
                    Text(category)
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(SemanticColors.surfaceSubtle)
                        .cornerRadius(CornerRadius.xs)
                }
            }
        }
        .padding(Spacing.lg)
        .background(SemanticColors.backgroundPrimary)
        .cornerRadius(CornerRadius.lg)
        .elevation(Elevation.low)
    }

    // Status badge view
    @ViewBuilder
    private var statusBadge: some View {
        switch bet.status {
        case .open:
            HStack(spacing: Spacing.xs) {
                Image(systemName: "clock.fill")
                Text("OPEN")
            }
            .statusBadge(.info)

        case .won:
            HStack(spacing: Spacing.xs) {
                Image(systemName: "trophy.fill")
                Text("WON")
            }
            .statusBadge(.success)

        case .lost:
            HStack(spacing: Spacing.xs) {
                Image(systemName: "xmark.circle.fill")
                Text("LOST")
            }
            .statusBadge(.error)

        case .claimed:
            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark.seal.fill")
                Text("CLAIMED")
            }
            .statusBadge(.custom(foreground: .purple, background: .purple.opacity(0.15)))
        }
    }

    // Avatar gradient based on wallet address
    private var avatarGradient: LinearGradient {
        let hash = bet.walletAddress.hashValue
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

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatPnl(_ pnl: Double) -> String {
        let prefix = pnl >= 0 ? "+" : ""
        return "\(prefix)$\(String(format: "%.0f", pnl))"
    }
}

#Preview {
    BetCardView(
        bet: PredictionBet(
            id: "1",
            walletAddress: "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
            walletNickname: "Whale Bettor",
            signature: "5abc123...",
            timestamp: Date().addingTimeInterval(-3600),
            marketAddress: "market123",
            marketTitle: "Will Bitcoin reach $100K by end of 2025?",
            marketCategory: "Crypto",
            direction: .yes,
            amount: 5000,
            shares: 7142.86,
            avgPrice: 0.70,
            status: .open,
            pnl: nil,
            canCopy: true
        )
    )
    .padding()
    .environmentObject(ThemeManager.shared)
}
