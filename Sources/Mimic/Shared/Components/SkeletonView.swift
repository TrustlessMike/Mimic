import SwiftUI

/// Generic skeleton loading view
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 20, cornerRadius: CGFloat = CornerRadius.sm) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(SemanticColors.surfaceSubtle)
            .frame(width: width, height: height)
            .shimmer()
    }
}

/// Skeleton for balance card
struct SkeletonBalanceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // "Total Balance" label skeleton
            SkeletonView(width: 120, height: 16, cornerRadius: CornerRadius.xs)

            // Large balance amount skeleton
            SkeletonView(width: 200, height: 40, cornerRadius: CornerRadius.sm)

            // "Today" change skeleton
            SkeletonView(width: 100, height: 14, cornerRadius: CornerRadius.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(SemanticColors.surfaceDefault)
        .cornerRadius(CornerRadius.lg)
    }
}

/// Skeleton for individual token row
struct SkeletonTokenRow: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Token icon skeleton
            Circle()
                .fill(SemanticColors.surfaceSubtle)
                .frame(width: 40, height: 40)
                .shimmer()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Token name skeleton
                SkeletonView(width: 80, height: 16, cornerRadius: CornerRadius.xs)

                // Token amount skeleton
                SkeletonView(width: 120, height: 14, cornerRadius: CornerRadius.xs)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                // USD value skeleton
                SkeletonView(width: 100, height: 16, cornerRadius: CornerRadius.xs)

                // 24h change skeleton
                SkeletonView(width: 60, height: 14, cornerRadius: CornerRadius.xs)
            }
        }
        .padding(Spacing.lg)
        .background(SemanticColors.surfaceDefault)
        .cornerRadius(CornerRadius.md)
    }
}

/// Skeleton for token list (multiple rows)
struct SkeletonTokenList: View {
    let count: Int

    init(count: Int = 3) {
        self.count = count
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonTokenRow()
            }
        }
    }
}

/// Skeleton for quote card (swap rates, price impact, etc)
struct SkeletonQuoteCard: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Exchange Rate row
            HStack {
                SkeletonView(width: 80, height: 14, cornerRadius: CornerRadius.xs)
                Spacer()
                SkeletonView(width: 150, height: 14, cornerRadius: CornerRadius.xs)
            }

            Divider()

            // Price Impact row
            HStack {
                SkeletonView(width: 100, height: 14, cornerRadius: CornerRadius.xs)
                Spacer()
                SkeletonView(width: 60, height: 14, cornerRadius: CornerRadius.xs)
            }

            Divider()

            // Minimum Received row
            HStack {
                SkeletonView(width: 120, height: 14, cornerRadius: CornerRadius.xs)
                Spacer()
                SkeletonView(width: 100, height: 14, cornerRadius: CornerRadius.xs)
            }

            Divider()

            // Slippage Tolerance row
            HStack {
                SkeletonView(width: 130, height: 14, cornerRadius: CornerRadius.xs)
                Spacer()
                SkeletonView(width: 50, height: 14, cornerRadius: CornerRadius.xs)
            }
        }
        .padding(Spacing.lg)
        .background(SemanticColors.surfaceDefault)
        .cornerRadius(CornerRadius.md)
    }
}

/// Skeleton for transaction row (activity feed)
struct SkeletonTransactionRow: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Transaction type icon skeleton
            Circle()
                .fill(SemanticColors.surfaceSubtle)
                .frame(width: 40, height: 40)
                .shimmer()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Transaction description skeleton
                SkeletonView(width: 120, height: 16, cornerRadius: CornerRadius.xs)

                // Transaction date skeleton
                SkeletonView(width: 80, height: 14, cornerRadius: CornerRadius.xs)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                // Amount skeleton
                SkeletonView(width: 90, height: 16, cornerRadius: CornerRadius.xs)

                // USD value skeleton
                SkeletonView(width: 60, height: 14, cornerRadius: CornerRadius.xs)
            }
        }
        .padding(Spacing.lg)
        .background(SemanticColors.surfaceDefault)
        .cornerRadius(CornerRadius.md)
    }
}

/// Skeleton for transaction list (multiple rows)
struct SkeletonTransactionList: View {
    let count: Int

    init(count: Int = 5) {
        self.count = count
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonTransactionRow()
            }
        }
    }
}

/// Skeleton for recipient chip (suggested contacts)
struct SkeletonRecipientChip: View {
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Circle()
                .fill(SemanticColors.surfaceSubtle)
                .frame(width: 52, height: 52)
                .shimmer()

            SkeletonView(width: 50, height: 12, cornerRadius: CornerRadius.xs)
        }
    }
}

/// Skeleton for recipient row (recent contacts)
struct SkeletonRecipientRow: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(SemanticColors.surfaceSubtle)
                .frame(width: 44, height: 44)
                .shimmer()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                SkeletonView(width: 100, height: 16, cornerRadius: CornerRadius.xs)
                SkeletonView(width: 80, height: 12, cornerRadius: CornerRadius.xs)
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }
}

/// Skeleton for recipient list (chips + rows)
struct SkeletonRecipientList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Suggested section skeleton
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SkeletonView(width: 70, height: 14, cornerRadius: CornerRadius.xs)
                    .padding(.horizontal, Spacing.lg)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.lg) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonRecipientChip()
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }

            // Recent section skeleton
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SkeletonView(width: 50, height: 14, cornerRadius: CornerRadius.xs)
                    .padding(.horizontal, Spacing.lg)

                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRecipientRow()
                            .padding(.horizontal, Spacing.lg)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Skeleton Components") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            Text("Skeleton Loading States")
                .font(Typography.headlineLarge)
                .fontWeight(.bold)

            Text("Balance Card")
                .font(Typography.headlineSmall)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.lg)

            SkeletonBalanceCard()
                .padding(.horizontal, Spacing.lg)

            Text("Token List")
                .font(Typography.headlineSmall)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.lg)

            SkeletonTokenList(count: 5)
                .padding(.horizontal, Spacing.lg)
        }
        .padding(.vertical, Spacing.lg)
    }
    .background(SemanticColors.backgroundPrimary)
}
