import SwiftUI

struct TestingInfoView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(BrandColors.primary.opacity(0.1))
                                .frame(width: 80, height: 80)

                            Image(systemName: "testtube.2")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(BrandColors.primary)
                        }

                        Text("Welcome, Tester!")
                            .font(.title.weight(.bold))

                        Text("Thanks for helping us test Wickett. Here's what to try:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // Testing checklist
                    VStack(alignment: .leading, spacing: 20) {
                        TestingItem(
                            number: 1,
                            title: "Add Funds",
                            description: "Use the \"Add\" button to buy crypto with Apple Pay or card (Coinbase handles this)"
                        )

                        TestingItem(
                            number: 2,
                            title: "Send a Payment",
                            description: "Tap \"Send\" and search for @jakey, @mike, or another tester to send them money"
                        )

                        TestingItem(
                            number: 3,
                            title: "Request Money",
                            description: "Tap \"Receive\" to create a payment request. Select a Wickett Team member and send it"
                        )

                        TestingItem(
                            number: 4,
                            title: "Test Notifications",
                            description: "Enable notifications to receive alerts when someone sends you a payment request"
                        )

                        TestingItem(
                            number: 5,
                            title: "Swap Tokens",
                            description: "Use \"Swap\" to convert between different cryptocurrencies like SOL, USDC, and more"
                        )

                        TestingItem(
                            number: 6,
                            title: "Set Up Auto-Convert",
                            description: "Configure your portfolio preferences in Settings to automatically convert incoming payments"
                        )
                    }
                    .padding(.horizontal, 24)

                    // Feedback note
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.title2)
                            .foregroundColor(.orange)

                        Text("Found a bug? Let us know via TestFlight feedback!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 100)
                }
            }

            // Continue button
            VStack(spacing: 16) {
                Button(action: onContinue) {
                    HStack {
                        Text("Continue Setup")
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
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .background(
                LinearGradient(
                    colors: [Color(UIColor.systemBackground).opacity(0), Color(UIColor.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                .allowsHitTesting(false),
                alignment: .top
            )
        }
    }
}

// MARK: - Testing Item Component

struct TestingItem: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(BrandColors.primary)
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    TestingInfoView(onContinue: {})
}
