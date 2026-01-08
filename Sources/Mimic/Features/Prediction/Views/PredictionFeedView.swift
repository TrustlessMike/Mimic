import SwiftUI

/// Clean, X-inspired feed showing prediction bets from smart money wallets
struct PredictionFeedView: View {
    @StateObject private var predictionService = PredictionService.shared
    @State private var selectedFilter: BetFeedFilter = .all
    @State private var showSmartMoneyList = false
    @State private var isLoadingMore = false

    // Scroll-to-hide header
    @State private var headerOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0

    private let headerHeight: CGFloat = 52

    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Scroll offset tracker
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetKey.self,
                                value: geo.frame(in: .named("feedScroll")).minY
                            )
                    }
                    .frame(height: 0)

                    // Spacer for header
                    Color.clear.frame(height: headerHeight)

                    // Filter Pills
                    filterRow
                        .padding(.vertical, 12)

                    // Divider
                    Divider()

                    // Content
                    if predictionService.betFeed.isEmpty && predictionService.isLoadingFeed {
                        loadingState
                    } else if predictionService.betFeed.isEmpty {
                        emptyState
                    } else {
                        feedContent
                    }
                }
            }
            .coordinateSpace(name: "feedScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                handleScroll(offset)
            }

            // Collapsible header
            stickyHeader
                .offset(y: headerOffset)
        }
        .background(Color(.systemBackground))
        .task {
            await loadData()
        }
        .refreshable {
            await refreshData()
        }
        .sheet(isPresented: $showSmartMoneyList) {
            SmartMoneyListSheet()
        }
    }

    // MARK: - Scroll Handling

    private func handleScroll(_ offset: CGFloat) {
        let delta = offset - lastScrollOffset

        // Calculate header offset based on scroll direction
        if delta < 0 && offset < 0 {
            // Scrolling down - hide header
            headerOffset = max(-headerHeight, headerOffset + delta * 0.5)
        } else if delta > 0 {
            // Scrolling up - show header
            headerOffset = min(0, headerOffset + delta * 0.5)
        }

        // Snap to fully shown/hidden when near threshold
        if offset > -20 {
            withAnimation(.easeOut(duration: 0.2)) { headerOffset = 0 }
        }

        lastScrollOffset = offset
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Feed")
                    .font(.system(size: 20, weight: .bold))

                Spacer()

                Button(action: { showSmartMoneyList = true }) {
                    Image(systemName: "person.2")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(SemanticColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(height: headerHeight)

            Divider()
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BetFeedFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                        Task {
                            await predictionService.refreshFeed(filter: filter)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(predictionService.betFeed) { bet in
                FeedBetCard(bet: bet)
                    .onAppear {
                        if bet.id == predictionService.betFeed.last?.id && !isLoadingMore {
                            Task {
                                isLoadingMore = true
                                defer { isLoadingMore = false }
                                await predictionService.loadMoreBets(filter: selectedFilter)
                            }
                        }
                    }

                Divider()
                    .padding(.leading, 68) // Align with content after avatar
            }

            if predictionService.isLoadingFeed {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(24)
                    Spacer()
                }
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonBetCard()
                Divider()
                    .padding(.leading, 68)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(Color(.tertiaryLabel))

            Text("No bets yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(SemanticColors.textPrimary)

            Text("When smart money wallets place bets,\nthey'll appear here")
                .font(.system(size: 15))
                .foregroundColor(SemanticColors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
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
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : SemanticColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(BrandColors.primary) : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Feed Bet Card (X-style)

private struct FeedBetCard: View {
    let bet: PredictionBet

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(avatarGradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(bet.displayName.prefix(1)).uppercased())
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 8) {
                // Header: Name + Time
                HStack(alignment: .firstTextBaseline) {
                    Text(bet.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SemanticColors.textPrimary)

                    Text(bet.shortenedAddress)
                        .font(.system(size: 14))
                        .foregroundColor(SemanticColors.textSecondary)

                    Spacer()

                    Text(timeAgo(from: bet.timestamp))
                        .font(.system(size: 14))
                        .foregroundColor(SemanticColors.textSecondary)
                }

                // Direction + Price
                HStack(spacing: 8) {
                    DirectionBadge(direction: bet.direction)

                    Text("@ \(Int(bet.avgPrice * 100))¢")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SemanticColors.textSecondary)

                    if bet.status != .open {
                        StatusIndicator(status: bet.status)
                    }
                }

                // Market Title
                if let title = bet.marketTitle {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundColor(SemanticColors.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Amount + Shares
                HStack(spacing: 16) {
                    Label {
                        Text(bet.formattedAmount)
                            .font(.system(size: 14, weight: .medium))
                    } icon: {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(SemanticColors.textSecondary)

                    Label {
                        Text("\(Int(bet.shares)) shares")
                            .font(.system(size: 14, weight: .medium))
                    } icon: {
                        Image(systemName: "ticket")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(SemanticColors.textSecondary)

                    if let pnl = bet.pnl, bet.status != .open {
                        Text(formatPnl(pnl))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(pnl >= 0 ? SemanticColors.success : SemanticColors.error)
                    }
                }
                .padding(.top, 4)

                // Action Row
                HStack(spacing: 24) {
                    ActionButton(icon: "arrow.up.right.square", label: "View") {
                        if let url = bet.explorerURL {
                            UIApplication.shared.open(url)
                        }
                    }

                    if bet.canCopy {
                        ActionButton(icon: "doc.on.doc", label: "Copy") {
                            // TODO: Copy action
                        }
                    }

                    Spacer()

                    if let category = bet.marketCategory {
                        Text(category)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SemanticColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
    }

    private var avatarGradient: LinearGradient {
        let hash = bet.walletAddress.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.65, brightness: 0.75),
                Color(hue: hue, saturation: 0.55, brightness: 0.55),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }

    private func formatPnl(_ pnl: Double) -> String {
        let prefix = pnl >= 0 ? "+" : ""
        return "\(prefix)$\(Int(pnl))"
    }
}

// MARK: - Direction Badge

private struct DirectionBadge: View {
    let direction: PredictionBet.BetDirection

    var body: some View {
        Text(direction.displayName)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(direction == .yes ? SemanticColors.success : SemanticColors.error)
            )
    }
}

// MARK: - Status Indicator

private struct StatusIndicator: View {
    let status: PredictionBet.BetStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(color)
    }

    private var icon: String {
        switch status {
        case .open: return "clock"
        case .won: return "checkmark.circle.fill"
        case .lost: return "xmark.circle.fill"
        case .claimed: return "checkmark.seal.fill"
        }
    }

    private var label: String {
        switch status {
        case .open: return "Open"
        case .won: return "Won"
        case .lost: return "Lost"
        case .claimed: return "Claimed"
        }
    }

    private var color: Color {
        switch status {
        case .open: return SemanticColors.textSecondary
        case .won: return SemanticColors.success
        case .lost: return SemanticColors.error
        case .claimed: return .purple
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(SemanticColors.textSecondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Skeleton Bet Card

private struct SkeletonBetCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 44, height: 44)
                .shimmer()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SkeletonShape(width: 100, height: 16)
                    SkeletonShape(width: 60, height: 14)
                    Spacer()
                    SkeletonShape(width: 30, height: 14)
                }

                SkeletonShape(width: 80, height: 24, cornerRadius: 12)

                SkeletonShape(height: 18)
                SkeletonShape(width: 200, height: 18)

                HStack {
                    SkeletonShape(width: 70, height: 16)
                    SkeletonShape(width: 80, height: 16)
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Smart Money List Sheet

private struct SmartMoneyListSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var predictionService = PredictionService.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(predictionService.smartMoneyWallets) { wallet in
                        SmartMoneyRow(wallet: wallet)
                    }
                } header: {
                    Text("Tracking \(predictionService.smartMoneyWallets.count) wallets")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Smart Money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }
}

// MARK: - Smart Money Row

private struct SmartMoneyRow: View {
    let wallet: SmartMoneyWallet

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(avatarGradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((wallet.nickname ?? wallet.address).prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(wallet.nickname ?? shortenAddress(wallet.address))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SemanticColors.textPrimary)

                Text("\(wallet.stats.totalBets) bets")
                    .font(.system(size: 13))
                    .foregroundColor(SemanticColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(wallet.stats.winRate * 100))%")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SemanticColors.success)

                Text("win rate")
                    .font(.system(size: 12))
                    .foregroundColor(SemanticColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var avatarGradient: LinearGradient {
        let hash = wallet.address.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.65, brightness: 0.75),
                Color(hue: hue, saturation: 0.55, brightness: 0.55),
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

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    PredictionFeedView()
        .environmentObject(ThemeManager.shared)
}
