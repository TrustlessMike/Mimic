import SwiftUI

/// Card displaying a single trade from a tracked wallet
struct TradeCardView: View {
    let trade: TrackedTrade
    let onCopy: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Wallet + Time
            HStack {
                // Wallet avatar
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(trade.displayName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(trade.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(trade.shortenedAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Timestamp
                Text(timeAgo(from: trade.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Trade Details
            HStack(spacing: 12) {
                // Trade type badge
                HStack(spacing: 4) {
                    Image(systemName: trade.type == .buy ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundColor(trade.type == .buy ? .green : .red)

                    Text(trade.type == .buy ? "BUY" : "SELL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(trade.type == .buy ? .green : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (trade.type == .buy ? Color.green : Color.red)
                        .opacity(0.15)
                )
                .cornerRadius(6)

                // Token swap
                HStack(spacing: 4) {
                    TokenPill(symbol: trade.inputToken.symbol, isInput: true)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TokenPill(symbol: trade.outputToken.symbol, isInput: false)
                }

                Spacer()

                // Degen warning
                if !trade.isSafeModeTrade {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                        Text("DEGEN")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
                }
            }

            // Amounts
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatAmount(trade.inputToken.amount))
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(trade.inputToken.symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatAmount(trade.outputToken.amount))
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(trade.outputToken.symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)

            // Action Buttons
            HStack(spacing: 12) {
                // View on Explorer
                Button(action: {
                    if let url = trade.explorerURL {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("View Tx")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Copy Trade Button
                Button(action: onCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text(trade.canCopy ? "Copy Trade" : "Enable Degen")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        trade.canCopy
                            ? BrandColors.primaryGradient
                            : LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // Avatar gradient based on wallet address
    private var avatarGradient: LinearGradient {
        let hash = trade.walletAddress.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.7, brightness: 0.8),
                Color(hue: hue, saturation: 0.6, brightness: 0.6),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatAmount(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.2fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "%.2fK", amount / 1_000)
        } else if amount >= 1 {
            return String(format: "%.2f", amount)
        } else {
            return String(format: "%.4f", amount)
        }
    }
}

/// Small pill showing token symbol
struct TokenPill: View {
    let symbol: String
    let isInput: Bool

    var body: some View {
        Text(symbol)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(4)
    }
}

#Preview {
    TradeCardView(
        trade: TrackedTrade(
            id: "1",
            walletAddress: "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
            walletNickname: "Whale Trader",
            signature: "5abc123...",
            timestamp: Date().addingTimeInterval(-3600),
            type: .buy,
            inputToken: TrackedTrade.TokenInfo(mint: "USDC", symbol: "USDC", amount: 5000, usdValue: 5000),
            outputToken: TrackedTrade.TokenInfo(mint: "SOL", symbol: "SOL", amount: 25.5, usdValue: 5100),
            isSafeModeTrade: true,
            canCopy: true
        ),
        onCopy: {}
    )
    .padding()
    .environmentObject(ThemeManager.shared)
}
