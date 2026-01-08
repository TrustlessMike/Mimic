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

    // Scroll-to-hide
    @State private var headerVisible = true
    @State private var lastOffset: CGFloat = 0

    // Header height (title + filters + divider + padding)
    private let headerContentHeight: CGFloat = 116

    var body: some View {
        GeometryReader { geometry in
            let safeAreaTop = geometry.safeAreaInsets.top
            let totalHeaderHeight = safeAreaTop + headerContentHeight

            ZStack(alignment: .top) {
                // Scrollable content
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header spacer
                        Color.clear.frame(height: headerContentHeight)

                        // Content
                        if predictionService.betFeed.isEmpty && predictionService.isLoadingFeed {
                            loadingState
                        } else if predictionService.betFeed.isEmpty {
                            emptyState
                        } else {
                            feedContent
                        }
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onChange(of: geo.frame(in: .global).minY) { oldValue, newValue in
                                    let delta = newValue - lastOffset

                                    // Scrolling down (content moving up)
                                    if delta < -5 && newValue < 100 {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            headerVisible = false
                                        }
                                    }
                                    // Scrolling up (content moving down)
                                    else if delta > 5 {
                                        withAnimation(.easeOut(duration: 0.2)) {
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

                // Header with safe area background
                VStack(spacing: 0) {
                    // Safe area fill
                    Color(.systemBackground)
                        .frame(height: safeAreaTop)

                    headerView
                }
                .background(.ultraThinMaterial)
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
    }

    // MARK: - Header

    private var headerView: some View {
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

            filterRow

            Divider()
        }
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
        // Copy bet details to clipboard
        let details = """
        \(bet.direction.displayName) on \(bet.marketTitle ?? "Unknown Market")
        Amount: \(bet.formattedAmount)
        Price: \(Int(bet.avgPrice * 100))¢
        Shares: \(Int(bet.shares))
        Market: \(bet.marketAddress)
        """
        UIPasteboard.general.string = details
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

    // MARK: - Data Loading

    private func loadData() async {
        async let wallets: () = copyTradingService.loadTrackedWallets()
        async let smartMoney: () = predictionService.loadSmartMoneyWallets()
        async let feed: () = predictionService.loadBetFeed(filter: selectedFilter, refresh: true)

        _ = await (wallets, smartMoney, feed)
        predictionService.startFeedListener()
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
        HStack(spacing: 0) {
            // Direction part (YES/NO)
            Text(direction.displayName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(directionColor)

            // Status part (Open/Won/Lost)
            HStack(spacing: 4) {
                Image(systemName: statusIcon)
                    .font(.system(size: 10, weight: .semibold))
                Text(statusLabel)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(directionColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(directionColor.opacity(0.15))
        }
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(directionColor.opacity(0.3), lineWidth: 1)
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
