import SwiftUI

struct LoginView: View {
    let onAppleSignIn: () async -> Void
    let onGoogleSignIn: () async -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // MAIN CONTENT GROUP
            VStack(spacing: 40) {
                Spacer()
                
                // Hero section
                VStack(spacing: 16) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        // Breathing animation instead of bounce
                        .scaleEffect(isAnimating ? 1.03 : 1.0)
                        .shadow(color: BrandColors.primary.opacity(isAnimating ? 0.3 : 0.15), radius: 20, x: 0, y: 10)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)

                    Text("Mimic")
                        .font(.largeTitle.weight(.bold))
                        .tracking(-0.5)

                    Text("Follow top traders. Copy their moves.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                // Feature highlights - left aligned with fixed width for centering
                VStack(alignment: .leading, spacing: 14) {
                    LoginFeatureRow(icon: "eye.fill", text: "Follow smart money")
                    LoginFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "See what's working")
                    LoginFeatureRow(icon: "doc.on.doc.fill", text: "Copy with one tap")
                }
                .fixedSize(horizontal: true, vertical: false)
                
                Spacer()
            }
            .padding(.bottom, 20)

            // SIGN IN SECTION
            VStack(spacing: 12) {
                // Apple Sign In Button
                Button(action: {
                    Task { await onAppleSignIn() }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "applelogo")
                            .font(.body)
                        Text("Continue with Apple")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(height: 54)
                    .frame(maxWidth: .infinity)
                    .background(colorScheme == .dark ? Color.white : Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Google Sign In Button
                Button(action: {
                    Task { await onGoogleSignIn() }
                }) {
                    HStack(spacing: 8) {
                        GoogleIcon()
                            .frame(width: 18, height: 18)
                        Text("Continue with Google")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(height: 54)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Terms and Privacy
            Text("By continuing, you agree to our Terms & Privacy Policy")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Login Feature Row
private struct LoginFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(BrandColors.primary.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BrandColors.primary)
            }

            Text(text)
                .font(.body.weight(.medium)) // Updated to semantic font
                .foregroundStyle(.primary.opacity(0.85))
        }
    }
}

// MARK: - Google Icon
private struct GoogleIcon: View {
    var body: some View {
        Image("GoogleLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

#Preview {
    LoginView(
        onAppleSignIn: {},
        onGoogleSignIn: {}
    )
}

#Preview("Dark Mode") {
    LoginView(
        onAppleSignIn: {},
        onGoogleSignIn: {}
    )
    .preferredColorScheme(.dark)
}
