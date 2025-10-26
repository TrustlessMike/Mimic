import SwiftUI

struct LoginView: View {
    let onAppleSignIn: () async -> Void
    let onGoogleSignIn: () async -> Void

    var body: some View {
        VStack(spacing: 30) {
            // Logo
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.top, 50)

            // App Name
            Text("Wickett")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            // Sign in section
            VStack(spacing: 20) {
                Text("Sign in to continue")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Powered by Privy + Firebase")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Apple Sign In Button
                SignInButton(
                    icon: "applelogo",
                    title: "Sign in with Apple",
                    backgroundColor: .black,
                    action: onAppleSignIn
                )

                // Google Sign In Button
                SignInButton(
                    icon: "g.circle.fill",
                    title: "Sign in with Google",
                    backgroundColor: Color(red: 0.26, green: 0.52, blue: 0.96),
                    action: onGoogleSignIn
                )
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Sign In Button Component
private struct SignInButton: View {
    let icon: String
    let title: String
    let backgroundColor: Color
    let action: () async -> Void

    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(8)
        }
    }
}
