import SwiftUI

/// Simple token detail view showing holdings
/// Charts removed - focus is on copy trading, not price speculation
struct TokenDetailView: View {
    let balance: TokenBalance

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Big price display
                    priceDisplay

                    // Your holdings
                    holdingsSection

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    TokenImageView(token: balance.token, size: 24)
                    Text(balance.token.name)
                        .font(.headline)
                }
            }
        }
    }

    // MARK: - Price Display

    private var priceDisplay: some View {
        VStack(spacing: 8) {
            Text(formatCurrency(balance.usdPrice))
                .font(.system(size: 44, weight: .bold, design: .rounded))

            if let change = balance.change24h {
                HStack(spacing: 6) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.subheadline.weight(.semibold))
                    Text(formatChange(change))
                        .font(.subheadline.weight(.semibold))
                    Text("Today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(change >= 0 ? .green : .red)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Holdings Section

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Holdings")
                .font(.headline)
                .padding(.horizontal)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(balance.displayAmount)
                        .font(.title3.weight(.bold))
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(balance.displayUSD)
                        .font(.title3.weight(.bold))
                    Text("Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = value < 1 ? 4 : 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private func formatChange(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        return formatter.string(from: (value / 100) as NSDecimalNumber) ?? "0%"
    }
}

#Preview {
    NavigationStack {
        TokenDetailView(
            balance: TokenBalance(
                id: "usdc",
                token: TokenRegistry.USDC,
                lamports: 100_000_000,
                usdPrice: 1.00,
                change24h: 0,
                lastUpdated: Date()
            )
        )
    }
}
