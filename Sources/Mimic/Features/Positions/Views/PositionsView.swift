import SwiftUI

/// View showing user's active prediction market positions with P&L
struct PositionsView: View {
    @StateObject private var positionsService = PositionsService.shared
    @State private var selectedFilter: PositionFilter = .open

    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Spacer for header
                    Color.clear.frame(height: 100)

                    // Content
                    if positionsService.isLoading && positionsService.positions.isEmpty {
                        loadingState
                    } else if filteredPositions.isEmpty {
                        emptyState
                    } else {
                        positionsContent
                    }
                }
            }

            // Sticky header
            stickyHeader
        }
        .background(Color(.systemBackground))
        .task {
            await positionsService.loadPositions()
            positionsService.startPositionsListener()
        }
        .onDisappear {
            positionsService.stopPositionsListener()
        }
        .refreshable {
            await positionsService.loadPositions()
        }
    }

    // MARK: - Filtered Positions

    private var filteredPositions: [UserPosition] {
        switch selectedFilter {
        case .open:
            return positionsService.positions.filter { $0.status == .open }
        case .won:
            return positionsService.positions.filter { $0.status == .won || $0.status == .claimed }
        case .lost:
            return positionsService.positions.filter { $0.status == .lost }
        case .all:
            return positionsService.positions
        }
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            // Summary card
            HStack(spacing: 16) {
                // Total P&L
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total P&L")
                        .font(.system(size: 13))
                        .foregroundColor(SemanticColors.textSecondary)

                    Text(formatPnl(positionsService.totalPnl))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(positionsService.totalPnl >= 0 ? SemanticColors.success : SemanticColors.error)
                }

                Spacer()

                // Stats
                HStack(spacing: 20) {
                    StatColumn(label: "Open", value: "\(positionsService.openCount)")
                    StatColumn(label: "Won", value: "\(positionsService.wonCount)")
                    StatColumn(label: "Win %", value: "\(positionsService.winRate)%")
                }
            }
            .padding(16)

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PositionFilter.allCases, id: \.self) { filter in
                        FilterPill(
                            title: filter.displayName,
                            count: countFor(filter),
                            isSelected: selectedFilter == filter
                        ) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedFilter = filter
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)

            Divider()
        }
        .background(.ultraThinMaterial)
    }

    private func countFor(_ filter: PositionFilter) -> Int {
        switch filter {
        case .open: return positionsService.openCount
        case .won: return positionsService.wonCount
        case .lost: return positionsService.lostCount
        case .all: return positionsService.positions.count
        }
    }

    // MARK: - Positions Content

    private var positionsContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredPositions) { position in
                PositionCard(position: position)
                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonPositionCard()
                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: selectedFilter == .open ? "chart.bar.doc.horizontal" : "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(Color(.tertiaryLabel))

            Text(emptyTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(SemanticColors.textPrimary)

            Text(emptySubtitle)
                .font(.system(size: 15))
                .foregroundColor(SemanticColors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    private var emptyTitle: String {
        switch selectedFilter {
        case .open: return "No open positions"
        case .won: return "No wins yet"
        case .lost: return "No losses"
        case .all: return "No positions yet"
        }
    }

    private var emptySubtitle: String {
        switch selectedFilter {
        case .open: return "Copy a bet from the feed to\nopen your first position"
        case .won: return "Your winning bets will appear here"
        case .lost: return "Lost positions will appear here"
        case .all: return "Your bet history will appear here"
        }
    }

    private func formatPnl(_ value: Double) -> String {
        let prefix = value >= 0 ? "+$" : "-$"
        return "\(prefix)\(String(format: "%.2f", abs(value)))"
    }
}

// MARK: - Position Filter

enum PositionFilter: String, CaseIterable {
    case open
    case won
    case lost
    case all

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .won: return "Won"
        case .lost: return "Lost"
        case .all: return "All"
        }
    }
}

// MARK: - Stat Column

private struct StatColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(SemanticColors.textPrimary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(SemanticColors.textSecondary)
        }
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color(.tertiarySystemBackground))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : SemanticColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(BrandColors.primary) : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Position Card

private struct PositionCard: View {
    let position: UserPosition
    @Environment(\.openURL) var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Direction + Status + Time
            HStack {
                BetStatusBadge(
                    direction: position.direction == "YES" ? .yes : .no,
                    status: mapStatus(position.status)
                )

                Spacer()

                Text(timeAgo(from: position.createdAt))
                    .font(.system(size: 13))
                    .foregroundColor(SemanticColors.textSecondary)
            }

            // Market title
            Text(position.marketTitle ?? "Unknown Market")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(SemanticColors.textPrimary)
                .lineLimit(2)

            // Position details
            HStack(spacing: 16) {
                DetailItem(label: "Entry", value: "\(Int(position.avgPrice * 100))¢")
                DetailItem(label: "Shares", value: "\(Int(position.shares))")
                DetailItem(label: "Cost", value: "$\(String(format: "%.0f", position.amount))")

                Spacer()

                // P&L
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatPnl(position.unrealizedPnl))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(position.unrealizedPnl >= 0 ? SemanticColors.success : SemanticColors.error)

                    if position.status == .open, let currentPrice = position.currentPrice {
                        Text("@ \(Int(currentPrice * 100))¢")
                            .font(.system(size: 12))
                            .foregroundColor(SemanticColors.textSecondary)
                    }
                }
            }

            // Action row for open positions
            if position.status == .open {
                HStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://jup.ag/perps/\(position.marketAddress)") {
                            openURL(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 14))
                            Text("View Market")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(SemanticColors.textSecondary)
                    }

                    Spacer()

                    // Current value
                    if let currentValue = position.currentValue {
                        Text("Value: $\(String(format: "%.2f", currentValue))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(SemanticColors.textSecondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
    }

    private func mapStatus(_ status: UserPosition.PositionStatus) -> PredictionBet.BetStatus {
        switch status {
        case .open: return .open
        case .won: return .won
        case .lost: return .lost
        case .claimed: return .claimed
        }
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    private func formatPnl(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)$\(String(format: "%.2f", value))"
    }
}

// MARK: - Detail Item

private struct DetailItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(SemanticColors.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(SemanticColors.textPrimary)
        }
    }
}

// MARK: - Bet Status Badge (reused from FeedView)

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

// MARK: - Skeleton Position Card

private struct SkeletonPositionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SkeletonShape(width: 100, height: 26, cornerRadius: 13)
                Spacer()
                SkeletonShape(width: 50, height: 14)
            }

            SkeletonShape(height: 18)
            SkeletonShape(width: 200, height: 18)

            HStack {
                SkeletonShape(width: 60, height: 32)
                SkeletonShape(width: 60, height: 32)
                SkeletonShape(width: 60, height: 32)
                Spacer()
                SkeletonShape(width: 80, height: 24)
            }
        }
        .padding(16)
    }
}

#Preview {
    PositionsView()
        .environmentObject(ThemeManager.shared)
}
