import SwiftUI
import FirebaseAuth
import UIKit

/// Clean, X-inspired feed showing prediction bets from smart money wallets
struct PredictionFeedView: View {
    @StateObject private var predictionService = PredictionService.shared
    @StateObject private var copyTradingService = CopyTradingService.shared
    @State private var selectedFilter: BetFeedFilter = .all
    @State private var showSmartMoneyList = false
    @State private var isLoadingMore = false
    @State private var selectedBetForDetail: PredictionBet?
    @State private var trackingWalletAddress: String?

    // Copy trade state
    @State private var selectedBetForCopy: PredictionBet?
    @State private var copyAmount: Double = 10
    @State private var isCopying = false
    @State private var copyError: String?
    @State private var showCopySuccess = false
    @State private var showDelegationSetup = false
    @StateObject private var predictionCopyService = PredictionCopyService.shared

    // Scroll-to-hide
    @State private var headerVisible = true
    @State private var lastOffset: CGFloat = 0

    // Header visual height (not including safe area - that's handled separately)
    private let headerVisualHeight: CGFloat = 92

    var body: some View {
        GeometryReader { geometry in
            let safeAreaTop = geometry.safeAreaInsets.top
            let totalHeaderHeight = safeAreaTop + headerVisualHeight

            ZStack(alignment: .top) {
                // Scrollable content
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Content - show hot markets or bet feed based on filter
                        if selectedFilter.showsHotMarkets {
                            // Trending tab - show hot markets
                            if predictionService.hotMarkets.isEmpty && predictionService.isLoadingHotMarkets {
                                loadingState
                            } else if predictionService.hotMarkets.isEmpty {
                                trendingEmptyState
                            } else {
                                hotMarketsContent
                            }
                        } else {
                            // Regular feed
                            if predictionService.betFeed.isEmpty && predictionService.isLoadingFeed {
                                loadingState
                            } else if predictionService.betFeed.isEmpty {
                                emptyState
                            } else {
                                feedContent
                            }
                        }

                        // Bottom padding for tab bar
                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, totalHeaderHeight)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onChange(of: geo.frame(in: .global).minY) { oldValue, newValue in
                                    let delta = newValue - lastOffset

                                    // Scrolling down (content moving up) - hide header
                                    if delta < -8 && newValue < 50 {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            headerVisible = false
                                        }
                                    }
                                    // Scrolling up (content moving down) - show header
                                    else if delta > 8 {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            headerVisible = true
                                        }
                                    }

                                    lastOffset = newValue
                                }
                        }
                    )
                }
                .refreshable {
                    await refreshData()
                }

                // Header overlay (X-style with material)
                VStack(spacing: 0) {
                    // Safe area material fill
                    Rectangle()
                        .fill(.clear)
                        .frame(height: safeAreaTop)

                    headerView
                }
                .background(.regularMaterial)
                .offset(y: headerVisible ? 0 : -totalHeaderHeight)
            }
            .ignoresSafeArea(.container, edges: .top)
            .background(Color(.systemBackground))
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showSmartMoneyList) {
            SmartMoneyListSheet()
        }
        .sheet(item: $selectedBetForDetail) { bet in
            BetDetailView(bet: bet)
        }
        .sheet(item: $selectedBetForCopy) { bet in
            copyTradeSheet(for: bet)
        }
        .alert("Copy Trade Submitted", isPresented: $showCopySuccess) {
            Button("OK") { }
        } message: {
            if predictionCopyService.delegationActive {
                Text("Your copy trade is being executed automatically.")
            } else {
                Text("Open Jupiter to complete your trade.")
            }
        }
        .alert("Copy Failed", isPresented: .init(
            get: { copyError != nil },
            set: { if !$0 { copyError = nil } }
        )) {
            Button("OK") { copyError = nil }
        } message: {
            Text(copyError ?? "Unknown error")
        }
        .task {
            await predictionCopyService.loadDelegationStatus()
        }
        .sheet(isPresented: $showDelegationSetup) {
            TrackedWalletsView()
        }
    }

    // MARK: - Copy Trade Sheet

    private func copyTradeSheet(for bet: PredictionBet) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Trade info
                VStack(spacing: 8) {
                    Text(bet.marketTitle ?? "Unknown Market")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(SemanticColors.textPrimary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        Text(bet.direction.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(bet.direction == .yes ? SemanticColors.success : SemanticColors.error)

                        Text("@")
                            .foregroundColor(SemanticColors.textSecondary)

                        Text("\(Int(bet.avgPrice * 100))¢")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SemanticColors.textPrimary)
                    }
                }
                .padding(.top, 8)

                Divider()

                // Amount selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Copy Amount (USDC)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SemanticColors.textSecondary)

                    HStack(spacing: 12) {
                        ForEach([5.0, 10.0, 25.0, 50.0], id: \.self) { amount in
                            Button(action: { copyAmount = amount }) {
                                Text("$\(Int(amount))")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(copyAmount == amount ? .white : SemanticColors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(copyAmount == amount ? Color(BrandColors.primary) : Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                            }
                        }
                    }

                    // Original bet comparison
                    Text("Original bet: \(bet.formattedAmount)")
                        .font(.system(size: 13))
                        .foregroundColor(SemanticColors.textSecondary)
                }

                // Delegation status
                VStack(spacing: 8) {
                    if predictionCopyService.delegationActive {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(SemanticColors.success)
                            Text("Auto-execute enabled")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(SemanticColors.success)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(SemanticColors.success.opacity(0.1))
                        .cornerRadius(10)
                    } else {
                        VStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(SemanticColors.textSecondary)
                                Text("Opens Jupiter to complete")
                                    .font(.system(size: 14))
                                    .foregroundColor(SemanticColors.textSecondary)
                            }

                            Button(action: {
                                selectedBetForCopy = nil
                                showDelegationSetup = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill")
                                    Text("Enable Auto-Execute")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(BrandColors.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(BrandColors.primary.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                }

                Spacer()

                // Execute button
                Button(action: { executeCopy(bet: bet) }) {
                    HStack {
                        if isCopying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: predictionCopyService.delegationActive ? "bolt.fill" : "arrow.up.right.square")
                            Text(predictionCopyService.delegationActive ? "Execute Copy" : "Open Jupiter")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isCopying ? Color.gray : Color(BrandColors.primary))
                    .cornerRadius(12)
                }
                .disabled(isCopying)
            }
            .padding(20)
            .navigationTitle("Copy Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        selectedBetForCopy = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func executeCopy(bet: PredictionBet) {
        isCopying = true

        Task {
            do {
                let result = try await predictionCopyService.initiateCopy(
                    bet: bet,
                    copyAmount: copyAmount
                )

                await MainActor.run {
                    selectedBetForCopy = nil
                    isCopying = false

                    if let jupiterUrl = result.jupiterUrl {
                        // Manual flow - open Jupiter
                        UIApplication.shared.open(jupiterUrl)
                    } else {
                        // Auto-execute flow - show success
                        showCopySuccess = true
                    }
                }
            } catch {
                await MainActor.run {
                    copyError = error.localizedDescription
                    isCopying = false
                }
            }
        }
    }

    // MARK: - Header (X-style)

    private var headerView: some View {
        VStack(spacing: 0) {
            // Top row: Title + Smart Money button
            HStack {
                Text("Feed")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SemanticColors.textPrimary)

                Spacer()

                Button(action: { showSmartMoneyList = true }) {
                    Image(systemName: "person.2")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(SemanticColors.textPrimary)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            // X-style tab bar with underline indicator
            filterTabBar
        }
    }

    // MARK: - Filter Tab Bar (X-style underlined tabs)

    private var filterTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(BetFeedFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                        Task {
                            await predictionService.refreshFeed(filter: filter)
                        }
                    }) {
                        VStack(spacing: 0) {
                            Text(filter.displayName)
                                .font(.system(size: 15, weight: selectedFilter == filter ? .bold : .regular))
                                .foregroundColor(selectedFilter == filter ? SemanticColors.textPrimary : SemanticColors.textSecondary)
                                .frame(height: 40)
                                .padding(.horizontal, 16)

                            // Underline indicator
                            Rectangle()
                                .fill(selectedFilter == filter ? Color(BrandColors.primary) : Color.clear)
                                .frame(height: 3)
                                .cornerRadius(1.5)
                                .padding(.horizontal, 8)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            // Bottom divider
            Rectangle()
                .fill(SemanticColors.divider.opacity(0.3))
                .frame(height: 0.5)
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(predictionService.betFeed) { bet in
                FeedBetCard(
                    bet: bet,
                    isWalletTracked: isWalletTracked(bet.walletAddress),
                    onViewTapped: {
                        selectedBetForDetail = bet
                    },
                    onTrackTapped: {
                        trackWallet(address: bet.walletAddress, nickname: bet.walletNickname)
                    },
                    onCopyTapped: {
                        copyBet(bet)
                    }
                )
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

    // MARK: - Wallet Tracking

    private func isWalletTracked(_ address: String) -> Bool {
        copyTradingService.trackedWallets.contains { $0.walletAddress == address }
    }

    private func copyBet(_ bet: PredictionBet) {
        print("📋 Copy tapped for bet: \(bet.id)")
        selectedBetForCopy = bet
    }

    private func trackWallet(address: String, nickname: String?) {
        // Prevent double-taps
        guard trackingWalletAddress == nil else {
            print("⚠️ Track already in progress, ignoring tap")
            return
        }
        trackingWalletAddress = address
        print("📡 Starting track for wallet: \(address)")

        Task {
            do {
                guard Auth.auth().currentUser != nil else {
                    print("❌ No Firebase user - cannot track wallet")
                    trackingWalletAddress = nil
                    return
                }

                // FirebaseCallableClient handles token refresh and retries
                try await copyTradingService.addTrackedWallet(address: address, nickname: nickname)
                print("✅ Wallet tracked successfully")
            } catch {
                print("❌ Track failed: \(error.localizedDescription)")
            }
            trackingWalletAddress = nil
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

    private var trendingEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "flame")
                .font(.system(size: 48))
                .foregroundColor(Color(.tertiaryLabel))

            Text("No trending markets")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(SemanticColors.textPrimary)

            Text("When multiple smart bettors converge\non the same market, it'll appear here")
                .font(.system(size: 15))
                .foregroundColor(SemanticColors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Hot Markets Content

    private var hotMarketsContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(predictionService.hotMarkets) { market in
                HotMarketCard(market: market)

                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        async let wallets: () = copyTradingService.loadTrackedWallets()
        async let smartMoney: () = predictionService.loadSmartMoneyWallets()
        async let feed: () = predictionService.loadBetFeed(filter: selectedFilter, refresh: true)
        async let hotMarkets: () = predictionService.loadHotMarkets()

        _ = await (wallets, smartMoney, feed, hotMarkets)
        predictionService.startFeedListener()
        predictionService.startHotMarketsListener()
        copyTradingService.startWalletsListener()
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
    let isWalletTracked: Bool
    var onViewTapped: (() -> Void)?
    var onTrackTapped: (() -> Void)?
    var onCopyTapped: (() -> Void)?

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

                // Direction + Status Badge + Price
                HStack(spacing: 8) {
                    BetStatusBadge(direction: bet.direction, status: bet.status)

                    Text("@ \(Int(bet.avgPrice * 100))¢")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SemanticColors.textSecondary)

                    // Kalshi price context
                    if let kalshiPrice = bet.formattedKalshiPrice {
                        Text("• Kalshi \(kalshiPrice)")
                            .font(.system(size: 13))
                            .foregroundColor(SemanticColors.textTertiary)
                    }
                }

                // Price comparison indicator
                if let comparison = bet.priceComparisonText, let diff = bet.priceVsKalshi {
                    HStack(spacing: 4) {
                        Image(systemName: diff < 0 ? "arrow.down.circle.fill" : (diff > 0 ? "arrow.up.circle.fill" : "equal.circle.fill"))
                            .font(.system(size: 11))
                        Text(comparison)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(diff < 0 ? SemanticColors.success : (diff > 0 ? SemanticColors.error : SemanticColors.textSecondary))
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
                HStack(spacing: 20) {
                    ActionButton(icon: "info.circle", label: "View") {
                        onViewTapped?()
                    }

                    if bet.canCopy {
                        ActionButton(icon: "doc.on.doc", label: "Copy") {
                            onCopyTapped?()
                        }
                    }

                    // Track button
                    if isWalletTracked {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Tracking")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(SemanticColors.success)
                    } else {
                        ActionButton(icon: "plus.circle", label: "Track") {
                            onTrackTapped?()
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

// MARK: - Combined Bet Status Badge

private struct BetStatusBadge: View {
    let direction: PredictionBet.BetDirection
    let status: PredictionBet.BetStatus

    private var directionColor: Color {
        direction == .yes ? SemanticColors.success : SemanticColors.error
    }

    // Status color based on outcome (not direction)
    private var statusColor: Color {
        switch status {
        case .won, .claimed: return SemanticColors.success
        case .lost: return SemanticColors.error
        case .open: return SemanticColors.textSecondary
        }
    }

    private var statusLabel: String {
        switch status {
        case .open: return "Open"
        case .won: return "Won"
        case .lost: return "Lost"
        case .claimed: return "Claimed"
        }
    }

    private var statusIcon: String {
        switch status {
        case .open: return "clock"
        case .won: return "checkmark.circle.fill"
        case .lost: return "xmark.circle.fill"
        case .claimed: return "checkmark.seal.fill"
        }
    }

    var body: some View {
        // Simple status badge - no YES/NO to avoid confusion
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 10, weight: .semibold))
            Text(statusLabel)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(statusColor.opacity(0.3), lineWidth: 1)
        )
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

// MARK: - Hot Market Card

private struct HotMarketCard: View {
    let market: HotMarket

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Heat indicator + Category
            HStack {
                // Heat badge
                HStack(spacing: 4) {
                    Text(market.heatEmoji)
                        .font(.system(size: 14))
                    Text(market.heatLevel.uppercased())
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(heatColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(heatColor.opacity(0.15))
                .clipShape(Capsule())

                Spacer()

                if let category = market.category {
                    Text(category)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SemanticColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(4)
                }
            }

            // Market title
            Text(market.marketTitle ?? "Unknown Market")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(SemanticColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Stats row
            HStack(spacing: 16) {
                // Bettors
                Label {
                    Text(market.formattedBettors)
                        .font(.system(size: 14, weight: .medium))
                } icon: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 13))
                }
                .foregroundColor(SemanticColors.textSecondary)

                // Volume
                if market.totalVolume > 0 {
                    Label {
                        Text(market.formattedVolume)
                            .font(.system(size: 14, weight: .medium))
                    } icon: {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(SemanticColors.textSecondary)
                }

                Spacer()

                // Consensus
                if market.consensusPercentage > 0 {
                    Text(market.formattedConsensus)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(consensusColor)
                }
            }

            // Time since detected
            if let detected = market.detectedAt {
                Text("Detected \(timeAgo(from: detected))")
                    .font(.system(size: 12))
                    .foregroundColor(SemanticColors.textTertiary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private var heatColor: Color {
        switch market.heatLevel {
        case "fire": return .orange
        case "hot": return .orange
        default: return SemanticColors.textSecondary
        }
    }

    private var consensusColor: Color {
        switch market.consensusDirection {
        case "YES": return SemanticColors.success
        case "NO": return SemanticColors.error
        default: return SemanticColors.textSecondary
        }
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - Smart Money List Sheet

private struct SmartMoneyListSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var copyTradingService = CopyTradingService.shared
    @State private var showAddWallet = false
    @State private var walletAddress = ""
    @State private var walletNickname = ""
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // Add Wallet Section
                Section {
                    if showAddWallet {
                        VStack(spacing: 12) {
                            TextField("Wallet Address", text: $walletAddress)
                                .font(.system(size: 15))
                                .autocapitalization(.none)
                                .autocorrectionDisabled()

                            TextField("Nickname (optional)", text: $walletNickname)
                                .font(.system(size: 15))

                            if let error = errorMessage {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(SemanticColors.error)
                            }

                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    withAnimation {
                                        showAddWallet = false
                                        walletAddress = ""
                                        walletNickname = ""
                                        errorMessage = nil
                                    }
                                }
                                .foregroundColor(SemanticColors.textSecondary)

                                Spacer()

                                Button(action: addWallet) {
                                    if isAdding {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Add")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .disabled(walletAddress.isEmpty || isAdding)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button(action: {
                            withAnimation {
                                showAddWallet = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color(BrandColors.primary))
                                Text("Add Wallet to Track")
                                    .foregroundColor(SemanticColors.textPrimary)
                            }
                        }
                    }
                }

                // Tracked Wallets Section
                Section {
                    if copyTradingService.trackedWallets.isEmpty {
                        Text("No wallets tracked yet")
                            .font(.system(size: 15))
                            .foregroundColor(SemanticColors.textSecondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(copyTradingService.trackedWallets) { wallet in
                            TrackedWalletRow(wallet: wallet)
                        }
                        .onDelete(perform: deleteWallets)
                    }
                } header: {
                    Text("Tracking \(copyTradingService.trackedWallets.count) wallets")
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
            .task {
                await copyTradingService.loadTrackedWallets()
            }
        }
    }

    private func addWallet() {
        guard !walletAddress.isEmpty else { return }

        isAdding = true
        errorMessage = nil

        Task {
            do {
                try await copyTradingService.addTrackedWallet(
                    address: walletAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                    nickname: walletNickname.isEmpty ? nil : walletNickname
                )

                await MainActor.run {
                    withAnimation {
                        showAddWallet = false
                        walletAddress = ""
                        walletNickname = ""
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isAdding = false
            }
        }
    }

    private func deleteWallets(at offsets: IndexSet) {
        for index in offsets {
            let wallet = copyTradingService.trackedWallets[index]
            Task {
                try? await copyTradingService.removeTrackedWallet(wallet)
            }
        }
    }
}

// MARK: - Tracked Wallet Row

private struct TrackedWalletRow: View {
    let wallet: TrackedWallet

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(avatarGradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((wallet.nickname ?? wallet.walletAddress).prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(wallet.nickname ?? shortenAddress(wallet.walletAddress))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SemanticColors.textPrimary)

                Text("\(wallet.stats.totalTrades) trades")
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
        let hash = wallet.walletAddress.hashValue
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


#Preview {
    PredictionFeedView()
        .environmentObject(ThemeManager.shared)
}
