import SwiftUI

/// Full-screen detail view for a prediction bet
struct BetDetailView: View {
    let bet: PredictionBet
    @Environment(\.dismiss) private var dismiss
    @StateObject private var copyService = PredictionCopyService.shared

    // Copy flow state
    @State private var showCopySheet = false
    @State private var copyAmount: Double = 10
    @State private var isCopying = false
    @State private var copyError: String?
    @State private var showCopySuccess = false
    @State private var pendingCopy: PendingCopyTrade?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    headerCard

                    // Market Info
                    marketCard

                    // Bet Details
                    detailsCard

                    // Kalshi Market Data (if available)
                    if bet.hasKalshiData {
                        kalshiCard
                    }

                    // Actions
                    actionsCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bet Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .sheet(isPresented: $showCopySheet) {
                copyTradeSheet
            }
            .alert("Copy Trade Submitted", isPresented: $showCopySuccess) {
                Button("OK") { }
            } message: {
                if copyService.delegationActive {
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
                await copyService.loadDelegationStatus()
            }
        }
    }

    // MARK: - Copy Trade Sheet

    private var copyTradeSheet: some View {
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
                    if copyService.delegationActive {
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
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(SemanticColors.textSecondary)
                            Text("Opens Jupiter to complete")
                                .font(.system(size: 14))
                                .foregroundColor(SemanticColors.textSecondary)
                        }
                    }
                }

                Spacer()

                // Execute button
                Button(action: executeCopy) {
                    HStack {
                        if isCopying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: copyService.delegationActive ? "bolt.fill" : "arrow.up.right.square")
                            Text(copyService.delegationActive ? "Execute Copy" : "Open Jupiter")
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
                        showCopySheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func executeCopy() {
        isCopying = true

        Task {
            do {
                let result = try await copyService.initiateCopy(
                    bet: bet,
                    copyAmount: copyAmount
                )

                await MainActor.run {
                    pendingCopy = result.pendingCopy
                    showCopySheet = false
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

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            // Wallet info
            HStack(spacing: 12) {
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(String(bet.displayName.prefix(1)).uppercased())
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(bet.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(SemanticColors.textPrimary)

                    Text(bet.shortenedAddress)
                        .font(.system(size: 14))
                        .foregroundColor(SemanticColors.textSecondary)
                }

                Spacer()

                // Status Badge
                statusBadge
            }

            Divider()

            // Direction + Price
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Position")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SemanticColors.textSecondary)

                    Text(bet.direction.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(bet.direction == .yes ? SemanticColors.success : SemanticColors.error)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Entry Price")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SemanticColors.textSecondary)

                    Text("\(bet.sharesEstimated == true ? "~" : "")\(Int(bet.avgPrice * 100))¢")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(SemanticColors.textPrimary)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Market Card

    private var marketCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Market")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SemanticColors.textSecondary)

                Spacer()

                if let category = bet.marketCategory {
                    Text(category)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SemanticColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(6)
                }
            }

            if let title = bet.marketTitle {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(SemanticColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Unknown Market")
                    .font(.system(size: 17))
                    .foregroundColor(SemanticColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "Amount", value: bet.formattedAmount)

            Divider().padding(.leading, 16)

            detailRow(label: "Shares", value: "\(bet.sharesEstimated == true ? "~" : "")\(String(format: "%.2f", bet.shares))")

            Divider().padding(.leading, 16)

            detailRow(label: "Avg Price", value: "\(bet.sharesEstimated == true ? "~" : "")\(String(format: "%.0f¢", bet.avgPrice * 100))")

            Divider().padding(.leading, 16)

            detailRow(label: "Time", value: formatDate(bet.timestamp))

            if let pnl = bet.pnl, bet.status != .open {
                Divider().padding(.leading, 16)

                HStack {
                    Text("P&L")
                        .font(.system(size: 15))
                        .foregroundColor(SemanticColors.textSecondary)

                    Spacer()

                    Text(formatPnl(pnl))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(pnl >= 0 ? SemanticColors.success : SemanticColors.error)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Kalshi Card

    private var kalshiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(BrandColors.primary)
                Text("Kalshi Market Data")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SemanticColors.textSecondary)
            }

            VStack(spacing: 0) {
                if let midPrice = bet.formattedKalshiPrice {
                    kalshiRow(label: "Mid Price", value: midPrice)
                    Divider().padding(.leading, 16)
                }

                if let yesBid = bet.kalshiYesBid {
                    kalshiRow(label: "Yes Bid", value: "\(Int(yesBid * 100))¢")
                    Divider().padding(.leading, 16)
                }

                if let yesAsk = bet.kalshiYesAsk {
                    kalshiRow(label: "Yes Ask", value: "\(Int(yesAsk * 100))¢")
                    Divider().padding(.leading, 16)
                }

                if let spread = bet.formattedKalshiSpread {
                    kalshiRow(label: "Spread", value: spread)
                    Divider().padding(.leading, 16)
                }

                if let comparison = bet.priceComparisonText, let diff = bet.priceVsKalshi {
                    HStack {
                        Text("Execution")
                            .font(.system(size: 15))
                            .foregroundColor(SemanticColors.textSecondary)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: diff < 0 ? "arrow.down.circle.fill" : (diff > 0 ? "arrow.up.circle.fill" : "equal.circle.fill"))
                                .font(.system(size: 12))
                            Text(comparison)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(diff < 0 ? SemanticColors.success : (diff > 0 ? SemanticColors.error : SemanticColors.textSecondary))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func kalshiRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(SemanticColors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(SemanticColors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(SemanticColors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(SemanticColors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: 12) {
            let _ = print("📊 actionsCard: canCopy=\(bet.canCopy), status=\(bet.status)")
            if bet.canCopy && bet.status == .open {
                Button(action: {
                    print("🔵 Copy button tapped! Showing sheet...")
                    showCopySheet = true
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Copy This Trade")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(BrandColors.primary))
                    .cornerRadius(12)
                }
            }

            Button(action: {
                if let url = bet.explorerURL {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("View on Solscan")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(SemanticColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 12, weight: .semibold))
            Text(statusLabel)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }

    private var statusIcon: String {
        switch bet.status {
        case .open: return "clock.fill"
        case .won: return "trophy.fill"
        case .lost: return "xmark.circle.fill"
        case .claimed: return "checkmark.seal.fill"
        }
    }

    private var statusLabel: String {
        switch bet.status {
        case .open: return "Open"
        case .won: return "Won"
        case .lost: return "Lost"
        case .claimed: return "Claimed"
        }
    }

    private var statusColor: Color {
        switch bet.status {
        case .open: return .blue
        case .won: return SemanticColors.success
        case .lost: return SemanticColors.error
        case .claimed: return .purple
        }
    }

    // MARK: - Helpers

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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatPnl(_ pnl: Double) -> String {
        let prefix = pnl >= 0 ? "+" : ""
        return "\(prefix)$\(String(format: "%.2f", pnl))"
    }
}

#Preview {
    BetDetailView(
        bet: PredictionBet(
            id: "1",
            walletAddress: "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
            walletNickname: "Sharp 85%",
            signature: "5abc123...",
            timestamp: Date().addingTimeInterval(-3600),
            marketAddress: "market123",
            marketTitle: "Will Bitcoin reach $100K by end of 2025?",
            marketCategory: "Crypto",
            direction: .yes,
            amount: 500,
            shares: 714.29,
            avgPrice: 0.70,
            status: .open,
            pnl: nil,
            canCopy: true
        )
    )
}
