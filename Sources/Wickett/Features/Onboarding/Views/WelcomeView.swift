import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // MAIN CONTENT
            VStack(spacing: 40) {
                Spacer()
                
                // Hero section
                VStack(spacing: 16) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .scaleEffect(isAnimating ? 1.03 : 1.0)
                        .shadow(color: BrandColors.primary.opacity(isAnimating ? 0.3 : 0.15), radius: 20, x: 0, y: 10)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)

                    Text("Welcome to Wickett")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .tracking(-0.5)
                }

                // Features
                VStack(alignment: .leading, spacing: 28) {
                    FeatureRow(
                        icon: "globe.americas.fill",
                        title: "Universal Payments",
                        description: "Pay in any currency, receive anything you want"
                    )

                    FeatureRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Smart Conversions",
                        description: "Get currency, crypto, stocks - whatever you prefer"
                    )

                    FeatureRow(
                        icon: "chart.bar.xaxis",
                        title: "Finance Hub",
                        description: "All your banking and finance tools in one place"
                    )
                }
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.bottom, 20)

            // BOTTOM SECTION
            VStack(spacing: 20) {
                // Continue Button
                Button(action: onContinue) {
                    HStack {
                        Text("Get Started")
                            .font(.headline.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(BrandColors.primary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: BrandColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                
                // Terms Footer (Implicit Consent)
                Text("By tapping Get Started, you agree to our ")
                    .foregroundColor(.secondary)
                    .font(.caption)
                + Text("Terms of Service")
                    .foregroundColor(BrandColors.primary)
                    .font(.caption.weight(.medium))
                + Text(" and ")
                    .foregroundColor(.secondary)
                    .font(.caption)
                + Text("Privacy Policy")
                    .foregroundColor(BrandColors.primary)
                    .font(.caption.weight(.medium))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(BrandColors.primary.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(BrandColors.primary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            // Center text vertically with the icon circle
            .padding(.top, 2)
        }
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
