import SwiftUI

struct ActivityView: View {
    let user: User

    @State private var searchText = ""
    @State private var selectedFilter: TransactionFilter = .all
    @State private var transactions: [Transaction] = []

    var filteredTransactions: [Transaction] {
        var result = transactions

        // Apply type filter
        if selectedFilter != .all {
            result = result.filter { transaction in
                switch selectedFilter {
                case .deposits:
                    return transaction.type == .deposit
                case .payments:
                    return transaction.type == .payment
                case .withdrawals:
                    return transaction.type == .withdrawal
                case .conversions:
                    return transaction.type == .conversion
                case .all:
                    return true
                }
            }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { transaction in
                transaction.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(TransactionFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                isSelected: selectedFilter == filter,
                                action: {
                                    selectedFilter = filter
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.systemBackground))

                Divider()

                // Transaction List
                if filteredTransactions.isEmpty {
                    EmptyActivityView(searchText: searchText, filter: selectedFilter)
                } else {
                    List {
                        ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                            Section {
                                ForEach(groupedTransactions[date] ?? []) { transaction in
                                    TransactionRow(transaction: transaction)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                }
                            } header: {
                                Text(formatSectionDate(date))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search transactions")
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadTransactions()
            }
        }
    }

    // MARK: - Helpers

    private var groupedTransactions: [String: [Transaction]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.timestamp).ISO8601Format()
        }
    }

    private func formatSectionDate(_ dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return dateString
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    private func loadTransactions() {
        // Mock data - will be replaced with real data from backend
        transactions = [
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
            ),
            Transaction(
                type: .payment,
                amount: 25.50,
                currency: "USD",
                description: "Lunch",
                timestamp: Date().addingTimeInterval(-345600)
            ),
            Transaction(
                type: .deposit,
                amount: 1000.00,
                currency: "USD",
                description: "Direct deposit",
                timestamp: Date().addingTimeInterval(-432000)
            ),
            Transaction(
                type: .withdrawal,
                amount: 200.00,
                currency: "USD",
                description: "ATM withdrawal",
                timestamp: Date().addingTimeInterval(-518400)
            ),
            Transaction(
                type: .payment,
                amount: 89.99,
                currency: "USD",
                description: "Grocery store",
                timestamp: Date().addingTimeInterval(-604800)
            ),
            Transaction(
                type: .conversion,
                amount: 50.00,
                currency: "USD",
                description: "Converted to SOL",
                timestamp: Date().addingTimeInterval(-691200)
            )
        ]
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Empty Activity View

struct EmptyActivityView: View {
    let searchText: String
    let filter: TransactionFilter

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text(emptyMessage)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(emptySubMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "No results found"
        } else if filter != .all {
            return "No \(filter.displayName.lowercased())"
        } else {
            return "No transactions yet"
        }
    }

    private var emptySubMessage: String {
        if !searchText.isEmpty {
            return "Try adjusting your search or filter"
        } else {
            return "Your activity will appear here"
        }
    }
}

// MARK: - Transaction Filter

enum TransactionFilter: CaseIterable {
    case all
    case deposits
    case payments
    case withdrawals
    case conversions

    var displayName: String {
        switch self {
        case .all: return "All"
        case .deposits: return "Deposits"
        case .payments: return "Payments"
        case .withdrawals: return "Withdrawals"
        case .conversions: return "Conversions"
        }
    }
}

#Preview {
    ActivityView(
        user: User(
            id: "test",
            email: "test@example.com",
            name: "Test User",
            walletAddress: "ABC123XYZ789"
        )
    )
}
