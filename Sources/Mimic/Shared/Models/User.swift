import Foundation

/// User model representing an authenticated user
struct User: Identifiable, Codable {
    let id: String
    let email: String?
    let name: String?
    let walletAddress: String?

    var displayName: String {
        name ?? email ?? "User"
    }

    var shortWalletAddress: String? {
        guard let wallet = walletAddress else { return nil }
        return String(wallet.prefix(6)) + "..." + String(wallet.suffix(4))
    }
}
