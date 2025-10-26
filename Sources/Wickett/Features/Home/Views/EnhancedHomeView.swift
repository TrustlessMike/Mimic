import SwiftUI

struct EnhancedHomeView: View {
    let user: User
    let onSettings: () -> Void
    let onSignOut: () async -> Void

    // Mock data for now - will be replaced with real data
    @State private var accountBalance = AccountBalance(totalBalanceUSD: 1234.56)
    @State private var recentTransactions: [Transaction] = [
        Transaction(
            type: .deposit,
            amount: 500.00,
            currency: "USD",
            description: "Paycheck deposit",
            timestamp: Date().addingTimeInterval(-86400)
        ),
        Transaction(
            type: .payment,
            amount: 45.99,
            currency: "USD",
            description: "Coffee shop",
            timestamp: Date().addingTimeInterval(-172800)
        ),
        Transaction(
            type: .conversion,
            amount: 100.00,
            currency: "USD",
            description: "Converted to SOL",
            timestamp: Date().addingTimeInterval(-259200)
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with greeting
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back,")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(user.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 20)

                // Account Balance Card
                AccountBalanceCard(balance: accountBalance)
                    .padding(.horizontal)

                // Recent Transactions
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Activity")
                            .font(.headline)
                        Spacer()
                        Button("View All") {
                            // TODO: Navigate to full transaction history
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)

                    if recentTransactions.isEmpty {
                        EmptyTransactionsView()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(recentTransactions) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Account Balance Card

struct AccountBalanceCard: View {
    let balance: AccountBalance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Text(balance.formattedBalance)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)

            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                Text("Updated \(timeAgo(balance.lastUpdated))")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Wallet Card

struct WalletCard: View {
    let walletAddress: String

    var shortAddress: String {
        String(walletAddress.prefix(6)) + "..." + String(walletAddress.suffix(4))
    }

    var body: some View {
        HStack {
            Image(systemName: "wallet.pass.fill")
                .font(.title2)
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 4) {
                Text("Solana Wallet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(shortAddress)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()

            Button(action: {
                UIPasteboard.general.string = walletAddress
            }) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Transaction icon
            Image(systemName: transaction.type.icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)

            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.body)
                    .fontWeight(.medium)

                Text(transaction.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount
            Text(transaction.formattedAmount)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(amountColor)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var iconColor: Color {
        switch transaction.type {
        case .payment: return .red
        case .deposit: return .green
        case .withdrawal: return .orange
        case .conversion: return .blue
        }
    }

    private var amountColor: Color {
        transaction.type == .deposit ? .green : .primary
    }
}

// MARK: - Empty Transactions View

struct EmptyTransactionsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No transactions yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Your recent activity will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    EnhancedHomeView(
        user: User(
            id: "test",
            email: "test@example.com",
            name: "Test User",
            walletAddress: "ABC123XYZ789ABC123XYZ789"
        ),
        onSettings: {},
        onSignOut: {}
    )
}
