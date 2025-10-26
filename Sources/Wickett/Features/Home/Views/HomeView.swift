import SwiftUI

struct HomeView: View {
    let user: User
    let onSignOut: () async -> Void

    var body: some View {
        VStack(spacing: 30) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding(.top, 50)

            // Welcome message
            Text("Welcome!")
                .font(.title2)
                .fontWeight(.semibold)

            // User information card
            UserInfoCard(user: user)
                .padding(.horizontal, 20)

            Spacer()

            // Sign out button
            Button(action: {
                Task {
                    await onSignOut()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.left.circle.fill")
                    Text("Sign Out")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(width: 200)
                .background(Color.red)
                .cornerRadius(10)
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - User Info Card Component
private struct UserInfoCard: View {
    let user: User

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("User Information:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if let email = user.email {
                    InfoRow(icon: "envelope.fill", text: email, color: .blue)
                }

                if let name = user.name {
                    InfoRow(icon: "person.fill", text: name, color: .blue)
                }

                if let wallet = user.walletAddress {
                    InfoRow(
                        icon: "wallet.pass.fill",
                        text: user.shortWalletAddress ?? wallet,
                        color: .purple
                    )
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

// MARK: - Info Row Component
private struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.body)
                .lineLimit(1)
        }
    }
}
