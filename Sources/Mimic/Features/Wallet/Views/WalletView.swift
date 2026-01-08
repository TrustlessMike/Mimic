import SwiftUI

struct WalletView: View {
    let user: User

    @EnvironmentObject var walletService: SolanaWalletService
    @State private var showError = false
    @State private var showBuy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Total Balance Card
                    if walletService.isLoading && walletService.balances.isEmpty {
                        SkeletonBalanceCard()
                            .padding(.horizontal, Spacing.lg)
                    } else {
                        TotalBalanceCard(
                            totalUSD: walletService.totalUSDValue,
                            change24h: walletService.total24hChange,
                            lastUpdated: walletService.lastUpdated
                        )
                        .padding(.horizontal, Spacing.lg)
                    }

                    // Quick Actions
                    HStack(spacing: Spacing.lg) {
                        WalletActionButton(
                            icon: "plus",
                            label: "Add Funds",
                            color: SemanticColors.success
                        ) { showBuy = true }
                    }
                    .padding(.horizontal, Spacing.lg)

                    // Token Holdings
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text("Holdings")
                            .font(Typography.headlineSmall)
                            .padding(.horizontal, Spacing.lg)

                        if walletService.isLoading && walletService.balances.isEmpty {
                            SkeletonTokenList(count: 5)
                                .padding(.horizontal, Spacing.lg)
                        } else if walletService.balances.filter({ $0.hasBalance }).isEmpty {
                            EmptyBalancesView()
                                .padding(.horizontal, Spacing.lg)
                        } else {
                            VStack(spacing: Spacing.sm) {
                                ForEach(walletService.balances.filter { $0.hasBalance }) { balance in
                                    NavigationLink(destination: TokenDetailView(balance: balance)) {
                                        TokenBalanceRow(balance: balance)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, Spacing.xl)
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                guard let walletAddress = user.walletAddress else { return }
                await walletService.refreshBalances(walletAddress: walletAddress, force: true)
            }
            .sheet(isPresented: $showBuy) { CoinbaseOnrampView() }
            .alert("Error", isPresented: $showError, presenting: walletService.error) { error in
                Button("OK") {
                    showError = false
                }
            } message: { error in
                Text(error.localizedDescription)
            }
            .onChange(of: walletService.error) { _, newError in
                showError = newError != nil
            }
        }
    }

}


// MARK: - Total Balance Card

struct TotalBalanceCard: View {
    let totalUSD: Decimal
    let change24h: Decimal?
    let lastUpdated: Date?

    private var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: totalUSD as NSDecimalNumber) ?? "$0.00"
    }

    private var formattedChange: String? {
        guard let change = change24h else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        return formatter.string(from: (change / 100) as NSDecimalNumber)
    }

    private var changeColor: Color {
        guard let change = change24h else { return SemanticColors.textSecondary }
        return change >= 0 ? SemanticColors.success : SemanticColors.error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Total Balance")
                    .font(Typography.bodyMedium)
                    .foregroundColor(SemanticColors.textOnGradient.opacity(0.8))

                Spacer()

                if let lastUpdated = lastUpdated {
                    Text("Updated \(timeAgo(lastUpdated))")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textOnGradient.opacity(0.6))
                }
            }

            Text(formattedTotal)
                .font(Typography.displayLarge)
                .foregroundColor(SemanticColors.textOnGradient)

            if let formattedChange = formattedChange {
                HStack(spacing: Spacing.xs + 2) {
                    Image(systemName: (change24h ?? 0) >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(Typography.labelSmall)
                        .fontWeight(.semibold)

                    Text(formattedChange)
                        .font(Typography.bodyMedium)
                        .fontWeight(.semibold)

                    Text("Today")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textOnGradient.opacity(0.8))
                }
                .foregroundColor(changeColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs + 2)
                .background(Color.black.opacity(0.2))
                .cornerRadius(CornerRadius.sm)
            }
        }
        .heroCard()
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        else if seconds < 3600 { return "\(seconds / 60)m ago" }
        else { return "\(seconds / 3600)h ago" }
    }
}


struct WalletActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            VStack(spacing: Spacing.xs + 2) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: IconSize.md, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(Typography.labelSmall)
                    .fontWeight(.medium)
                    .foregroundColor(SemanticColors.textPrimary)
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: AnimationTiming.springResponse, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Token Balance Row

struct TokenBalanceRow: View {
    let balance: TokenBalance

    var body: some View {
        HStack(spacing: Spacing.md) {
            TokenImageView(token: balance.token, size: 44)
                .elevation(Elevation.low)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(balance.token.name)
                    .font(Typography.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(SemanticColors.textPrimary)
                Text(balance.token.symbol)
                    .font(Typography.bodyMedium)
                    .foregroundColor(SemanticColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(balance.displayUSD)
                    .font(Typography.bodyLarge)
                    .fontWeight(.bold)
                    .foregroundColor(SemanticColors.textPrimary)

                if let change = balance.change24h {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(Typography.labelSmall)
                        Text(formatPercentage(change))
                            .font(Typography.labelSmall)
                    }
                    .foregroundColor(change >= 0 ? SemanticColors.success : SemanticColors.error)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private func formatPercentage(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        return formatter.string(from: (value / 100) as NSDecimalNumber) ?? "0%"
    }
}

// MARK: - Empty Balances View
struct EmptyBalancesView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "bitcoinsign.circle")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(SemanticColors.textSecondary.opacity(0.5))
            Text("No tokens yet")
                .font(Typography.bodyMedium)
                .foregroundColor(SemanticColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }
}


#Preview {
    WalletView(
        user: User(
            id: "test",
            email: "test@example.com",
            name: "Test User",
            walletAddress: "ABC123XYZ789"
        )
    )
}
