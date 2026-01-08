import Foundation
import AuthenticationServices
import Combine
import FirebaseFirestore
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "AuthCoordinator")

@MainActor
class AuthCoordinator: ObservableObject {
    static let shared = AuthCoordinator()

    private let hybridPrivyService = HybridPrivyService.shared
    private let db = Firestore.firestore()

    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: User?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Observe HybridPrivyService auth state
        hybridPrivyService.$isAuthenticated
            .sink { [weak self] authenticated in
                self?.isAuthenticated = authenticated
            }
            .store(in: &cancellables)

        hybridPrivyService.$currentUser
            .sink { [weak self] user in
                self?.currentUser = user
            }
            .store(in: &cancellables)
    }

    // MARK: - Sign In with Privy OAuth (Apple)

    func signInWithPrivyOAuth() async throws {
        isLoading = true
        errorMessage = nil

        do {
            // HybridPrivyService handles:
            // 1. Privy OAuth authentication
            // 2. Firebase custom token creation
            // 3. Firebase sign-in
            // 4. User data sync
            try await hybridPrivyService.authenticateWithPrivyOAuth()

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Sign In with Privy OAuth (Google)

    func signInWithPrivyGoogle() async throws {
        isLoading = true
        errorMessage = nil

        do {
            try await hybridPrivyService.authenticateWithPrivyGoogle()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Sign Out

    func signOut() async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Sign out from both Privy and Firebase
            try await hybridPrivyService.signOut()

            // Clear portfolio history for this session
            PortfolioHistoryManager.shared.clearHistory()

            currentUser = nil
            isAuthenticated = false
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Check Authentication Status

    func checkAuthenticationStatus() async {
        let authenticated = await hybridPrivyService.isUserAuthenticated()

        await MainActor.run {
            self.isAuthenticated = authenticated

            // If authenticated, restore user from HybridPrivyService
            if authenticated {
                self.currentUser = hybridPrivyService.currentUser
            }
        }

        // Fetch displayName from Firestore if authenticated
        if authenticated, let userId = currentUser?.id {
            await fetchDisplayName(userId: userId)
        }
    }

    // MARK: - Fetch User Data

    private func fetchDisplayName(userId: String) async {
        await fetchUserData(userId: userId)
    }

    /// Fetches user data from Firestore and updates currentUser
    func fetchUserData(userId: String? = nil) async {
        let uid = userId ?? currentUser?.id
        guard let uid = uid else { return }

        do {
            let document = try await db.collection("users").document(uid).getDocument()

            if document.exists, let data = document.data() {
                let displayName = data["displayName"] as? String

                // Update current user with fetched data
                await MainActor.run {
                    if let user = self.currentUser {
                        self.currentUser = User(
                            id: user.id,
                            email: user.email,
                            name: displayName ?? user.name,
                            walletAddress: user.walletAddress
                        )
                    }
                }
            }
        } catch {
            logger.error("Failed to fetch user data: \(error.localizedDescription)")
        }
    }
}
