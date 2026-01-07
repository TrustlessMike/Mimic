import SwiftUI

/// Main feed view showing trades from tracked wallets
struct FeedView: View {
    @StateObject private var trackingService = TrackingService.shared
    @State private var selectedFilter: TradeFeedFilter = .all
    @State private var showAddWallet = false
    @State private var showCopyTradeSheet = false
    @State private var selectedTrade: TrackedTrade?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Chips
                filterChips
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // Content
                if trackingService.trackedWallets.isEmpty && !trackingService.isLoadingWallets {
                    emptyState
                } else if trackingService.tradeFeed.isEmpty && !trackingService.isLoadingFeed {
                    noTradesState
                } else {
                    tradeFeedList
                }
            }
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddWallet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
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
            .sheet(isPresented: $showAddWallet) {
                AddWalletView()
            }
            .sheet(item: $selectedTrade) { trade in
                CopyTradeSheet(trade: trade)
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TradeFeedFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        Task {
                            await trackingService.refreshFeed(filter: filter)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Trade Feed List

    private var tradeFeedList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(trackingService.tradeFeed) { trade in
                    TradeCardView(trade: trade) {
                        selectedTrade = trade
                    }
                    .onAppear {
                        // Load more when reaching end
                        if trade.id == trackingService.tradeFeed.last?.id {
                            Task {
                                await trackingService.loadMoreTrades(filter: selectedFilter)
                            }
                        }
                    }
                }

                if trackingService.isLoadingFeed {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100) // Space for tab bar
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("Start Tracking Wallets")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Add wallet addresses to track their trades in real-time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: { showAddWallet = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Wallet")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(BrandColors.primaryGradient)
                .cornerRadius(12)
            }

            Spacer()
        }
    }

    private var noTradesState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Trades Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Waiting for trades from your tracked wallets...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Show tracked wallets count
            Text("Tracking \(trackingService.trackedWallets.count) wallet\(trackingService.trackedWallets.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        await trackingService.loadTrackedWallets()
        await trackingService.loadTradeFeed(filter: selectedFilter, refresh: true)
    }

    private func refreshData() async {
        await trackingService.loadTrackedWallets()
        await trackingService.refreshFeed(filter: selectedFilter)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? BrandColors.primaryGradient
                    : LinearGradient(colors: [Color(UIColor.secondarySystemBackground)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(20)
        }
    }
}

// MARK: - Copy Trade Sheet

struct CopyTradeSheet: View {
    let trade: TrackedTrade
    @Environment(\.dismiss) var dismiss
    @State private var amount: String = ""
    @State private var isExecuting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Trade Summary
                VStack(spacing: 12) {
                    HStack {
                        Text("Copy Trade")
                            .font(.headline)
                        Spacer()
                        if !trade.isSafeModeTrade {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                Text("DEGEN")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(6)
                        }
                    }

                    HStack {
                        VStack(alignment: .leading) {
                            Text(trade.inputToken.symbol)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Input")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(trade.outputToken.symbol)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Output")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }

                // Degen Warning
                if !trade.canCopy {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Enable Degen Mode in Settings to copy this trade")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }

                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount (\(trade.inputToken.symbol))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("0.00", text: $amount)
                        .font(.system(size: 32, weight: .bold))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }

                Spacer()

                // Execute Button
                Button(action: executeCopyTrade) {
                    if isExecuting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Execute Copy Trade")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    trade.canCopy && !amount.isEmpty
                        ? BrandColors.primaryGradient
                        : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
                .disabled(!trade.canCopy || amount.isEmpty || isExecuting)
            }
            .padding()
            .navigationTitle("Copy Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func executeCopyTrade() {
        // TODO: Implement copy trade execution
        isExecuting = true

        // Placeholder for actual implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExecuting = false
            dismiss()
        }
    }
}

// Make TrackedTrade identifiable for sheet
extension TrackedTrade: Equatable {
    static func == (lhs: TrackedTrade, rhs: TrackedTrade) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    FeedView()
        .environmentObject(ThemeManager.shared)
}
