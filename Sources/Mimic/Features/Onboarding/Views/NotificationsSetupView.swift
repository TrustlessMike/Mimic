import SwiftUI

struct NotificationsSetupView: View {
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(BrandColors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 50))
                    .foregroundColor(BrandColors.primary)
            }

            // Title
            Text("Never Miss a Trade")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Description
            Text("Get notified when tracked wallets make trades, when copy trades execute, and more.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Benefits list
            VStack(alignment: .leading, spacing: 16) {
                NotificationBenefitRow(
                    icon: "eye.fill",
                    text: "Tracked wallet activity"
                )
                NotificationBenefitRow(
                    icon: "checkmark.circle.fill",
                    text: "Copy trade executed"
                )
                NotificationBenefitRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Portfolio updates"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button(action: onEnable) {
                    HStack {
                        Image(systemName: "bell.fill")
                        Text("Enable Notifications")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(BrandColors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                Button(action: onSkip) {
                    Text("Maybe Later")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding()
    }
}

struct NotificationBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 28)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    NotificationsSetupView(
        onEnable: {},
        onSkip: {}
    )
}
