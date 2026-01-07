import SwiftUI

// MARK: - Sparkline Chart

struct SparklineChart: Shape {
    var dataPoints: [Double]
    var closePath: Bool = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard dataPoints.count > 1 else { return path }

        let stepX = rect.width / CGFloat(dataPoints.count - 1)
        let minPoint = dataPoints.min() ?? 0
        let maxPoint = dataPoints.max() ?? 1
        let range = maxPoint - minPoint

        if range == 0 {
            let yPosition = rect.height * 0.5
            path.move(to: CGPoint(x: 0, y: yPosition))
            path.addLine(to: CGPoint(x: rect.width, y: yPosition))
            if closePath {
                path.addLine(to: CGPoint(x: rect.width, y: rect.height))
                path.addLine(to: CGPoint(x: 0, y: rect.height))
                path.closeSubpath()
            }
            return path
        }

        let yRatio = rect.height / range
        let p1 = CGPoint(x: 0, y: rect.height - (dataPoints[0] - minPoint) * yRatio)
        path.move(to: p1)

        for index in 1..<dataPoints.count {
            let p2 = CGPoint(
                x: stepX * CGFloat(index),
                y: rect.height - (dataPoints[index] - minPoint) * yRatio
            )
            path.addLine(to: p2)
        }
        
        if closePath {
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Enhanced Home View

struct EnhancedHomeView: View {
    let onSettings: () -> Void
    let onSignOut: () async -> Void
    let onPayTap: () -> Void
    let onRequestTap: () -> Void
    let onAddFunds: () -> Void
    let onSeeAllAssets: () -> Void
    let onSeeAllActivity: () -> Void

    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var walletService: SolanaWalletService
    @ObservedObject private var historyManager = PortfolioHistoryManager.shared

    @State private var showDisplayName = false

    // MARK: - Computed Properties

    private var user: User? { authCoordinator.currentUser }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    private var userName: String {
        if showDisplayName {
            return user?.displayName ?? "User"
        } else {
            if let username = user?.username {
                return "@\(username)"
            }
            return user?.displayName ?? "User"
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Header
                HeaderSection(
                    greeting: greeting,
                    userName: userName,
                    onSettings: onSettings,
                    onToggleName: { showDisplayName.toggle() }
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Balance Hero
                BalanceHeroSection(
                    chartData: historyManager.chartData
                )
                .padding(.horizontal, 24)

                // Quick Actions
                QuickActionsSection(
                    onPayTap: onPayTap,
                    onRequestTap: onRequestTap,
                    onAddFunds: onAddFunds
                )
                .padding(.horizontal, 24)

                // Assets Section
                AssetsSection(onSeeAll: onSeeAllAssets)
                    .padding(.horizontal, 24)

                // Activity Section
                ActivitySection(
                    onAddFunds: onAddFunds,
                    onSeeAll: onSeeAllActivity
                )
                .padding(.horizontal, 24)

                // Bottom spacing
                Spacer(minLength: 100)
            }
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Header Section

struct HeaderSection: View {
    let greeting: String
    let userName: String
    let onSettings: () -> Void
    let onToggleName: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.body)
                    .foregroundColor(.secondary)

                Button(action: onToggleName) {
                    Text(userName)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Balance Hero Section

struct BalanceHeroSection: View {
    @EnvironmentObject var walletService: SolanaWalletService
    let chartData: [Double]

    private var totalUSD: Decimal { walletService.totalUSDValue }
    private var change24h: Decimal? { walletService.total24hChange }
    private var hasBalances: Bool { !walletService.balances.isEmpty }
    private var isLoading: Bool { walletService.isLoading }

    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: totalUSD)) ?? "$0.00"
    }

    private var formattedChange: String {
        guard let change = change24h else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        let decimal = change / 100
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? ""
    }

    private var isPositiveChange: Bool {
        (change24h ?? 0) >= 0
    }

    var body: some View {
        VStack(spacing: 8) {
            // Balance
            if isLoading && !hasBalances {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray6))
                    .frame(width: 200, height: 60)
                    .shimmer()
            } else {
                Text(formattedBalance)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(-1)
            }

            // 24h Change
            if let _ = change24h {
                HStack(spacing: 6) {
                    Image(systemName: isPositiveChange ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 14, weight: .bold))

                    Text(formattedChange)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(isPositiveChange ? .green : .red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (isPositiveChange ? Color.green : Color.red).opacity(0.1)
                )
                .cornerRadius(20)
            }

            // Chart
            if chartData.count >= 5 && totalUSD > 1 {
                ZStack {
                    // Gradient Fill
                    SparklineChart(dataPoints: chartData, closePath: true)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (isPositiveChange ? Color.green : Color.red).opacity(0.15),
                                    (isPositiveChange ? Color.green : Color.red).opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Line Stroke
                    SparklineChart(dataPoints: chartData, closePath: false)
                        .stroke(
                            isPositiveChange ? Color.green : Color.red,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                }
                .frame(height: 80)
                .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    let onPayTap: () -> Void
    let onRequestTap: () -> Void
    let onAddFunds: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            HomeQuickActionButton(
                icon: "arrow.up",
                label: "Pay",
                color: BrandColors.primary,
                action: onPayTap
            )

            Spacer()

            HomeQuickActionButton(
                icon: "arrow.down",
                label: "Request",
                color: .green,
                action: onRequestTap
            )

            Spacer()

            HomeQuickActionButton(
                icon: "plus",
                label: "Add",
                color: .orange,
                action: onAddFunds
            )

            Spacer()
        }
    }
}

struct HomeQuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 64, height: 64)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Assets Section

struct AssetsSection: View {
    @EnvironmentObject var walletService: SolanaWalletService
    let onSeeAll: () -> Void

    private var topTokens: [TokenBalance] {
        Array(
            walletService.balances
                .filter { $0.hasBalance }
                .sorted { $0.usdValue > $1.usdValue }
                .prefix(3)
        )
    }

    private var isLoading: Bool { walletService.isLoading }
    private var hasTokens: Bool { !topTokens.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Your Assets")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if hasTokens {
                    Button(action: onSeeAll) {
                        Text("See All")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(BrandColors.primary)
                    }
                }
            }

            // Content
            if isLoading && !hasTokens {
                // Skeleton loading
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        HomeSkeletonTokenRow()
                        if index < 2 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            } else if hasTokens {
                VStack(spacing: 0) {
                    ForEach(Array(topTokens.enumerated()), id: \.element.id) { index, balance in
                        AssetRow(balance: balance)

                        if index < topTokens.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            } else {
                // Empty state
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 56, height: 56)
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }

                    Text("No assets yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }
}

struct AssetRow: View {
    let balance: TokenBalance

    var body: some View {
        HStack(spacing: 16) {
            // Token Icon
            TokenImageView(token: balance.token, size: 40)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

            // Token Info
            VStack(alignment: .leading, spacing: 4) {
                Text(balance.token.symbol)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(balance.displayAmount)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Value & Change
            VStack(alignment: .trailing, spacing: 4) {
                Text(balance.displayUSD)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let changeText = balance.display24hChange {
                    Text(changeText)
                        .font(.caption.weight(.medium))
                        .foregroundColor(balance.isPositiveChange ? .green : .red)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

struct HomeSkeletonTokenRow: View {
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 40, height: 40)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(width: 50, height: 16)
                    .shimmer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(width: 80, height: 12)
                    .shimmer()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(width: 70, height: 16)
                    .shimmer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(width: 45, height: 12)
                    .shimmer()
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Activity Section

struct ActivitySection: View {
    @ObservedObject private var activityService = ActivityService.shared
    let onAddFunds: () -> Void
    let onSeeAll: () -> Void

    private var recentActivities: [ActivityItem] {
        Array(activityService.activities.prefix(3))
    }

    private var isLoading: Bool { activityService.isLoading }
    private var hasActivities: Bool { !activityService.activities.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if hasActivities {
                    Button(action: onSeeAll) {
                        Text("See All")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(BrandColors.primary)
                    }
                }
            }

            // Content
            if isLoading && !hasActivities {
                // Skeleton loading
                VStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { index in
                        HomeSkeletonActivityRow()
                        if index < 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            } else if hasActivities {
                VStack(spacing: 0) {
                    ForEach(Array(recentActivities.enumerated()), id: \.element.id) { index, activity in
                        HomeActivityRow(activity: activity)

                        if index < recentActivities.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            } else {
                // Welcome card for new users
                WelcomeCard(onAddFunds: onAddFunds)
            }
        }
        .task {
            if activityService.activities.isEmpty {
                await activityService.fetchActivity()
            }
        }
    }
}

struct HomeActivityRow: View {
    let activity: ActivityItem

    private var iconName: String {
        switch activity.type {
        case .paymentSent: return "arrow.up.right"
        case .paymentReceived: return "arrow.down.left"
        case .requestSent: return "paperplane.fill"
        case .requestReceived: return "envelope.fill"
        case .autoConvert: return "arrow.triangle.2.circlepath"
        }
    }

    private var iconColor: Color {
        switch activity.type {
        case .paymentSent: return .primary
        case .paymentReceived: return .green
        case .requestSent: return BrandColors.primary
        case .requestReceived: return .orange
        case .autoConvert: return .blue
        }
    }
    
    private var iconBackground: Color {
        switch activity.type {
        case .paymentSent: return Color(.systemGray5)
        case .paymentReceived: return Color.green.opacity(0.1)
        case .requestSent: return BrandColors.primary.opacity(0.1)
        case .requestReceived: return Color.orange.opacity(0.1)
        case .autoConvert: return Color.blue.opacity(0.1)
        }
    }

    private var amountColor: Color {
        switch activity.type {
        case .paymentReceived: return .green
        default: return .primary
        }
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2

        let prefix = activity.type == .paymentReceived ? "+" :
                     activity.type == .paymentSent ? "-" : ""

        if let formatted = formatter.string(from: NSNumber(value: abs(activity.amount))) {
            return prefix + formatted
        }
        return "$0.00"
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: activity.timestamp, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(relativeTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount
            Text(formattedAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(amountColor)
        }
        .padding(.vertical, 10)
    }
}

struct HomeSkeletonActivityRow: View {
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 40, height: 40)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(width: 120, height: 14)
                    .shimmer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(width: 60, height: 12)
                    .shimmer()
            }

            Spacer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray6))
                .frame(width: 60, height: 16)
                .shimmer()
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Welcome Card

struct WelcomeCard: View {
    let onAddFunds: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(BrandColors.primary)

            Text("Welcome to Wickett!")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Add funds to start sending money to friends")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button(action: onAddFunds) {
                Text("Add Funds")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BrandColors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
        .padding(.vertical, 28)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    EnhancedHomeView(
        onSettings: {},
        onSignOut: {},
        onPayTap: {},
        onRequestTap: {},
        onAddFunds: {},
        onSeeAllAssets: {},
        onSeeAllActivity: {}
    )
    .environmentObject(AuthCoordinator.shared)
    .environmentObject(SolanaWalletService.shared)
}
