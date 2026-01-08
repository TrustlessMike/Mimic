import Foundation
import PrivySDK
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "HybridPrivyService")

/// Service that bridges Privy authentication with Firebase
/// Implements the pattern: Privy Auth → Firebase Custom Token → Firebase Session
@MainActor
class HybridPrivyService: ObservableObject {
    static let shared = HybridPrivyService()

    private var privyClient: (any Privy)?
    private let firebaseCallable = FirebaseCallableClient.shared

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var walletAddress: String?

    private var authenticatedEmail: String?

    /// Public accessor for Privy client (used by DelegationManager for session approvals)
    var client: (any Privy)? {
        return privyClient
    }

    private init() {
        initializePrivySDK()
    }

    // MARK: - Initialization

    private func initializePrivySDK() {
        let loggingConfig = PrivyLoggingConfig(logLevel: .error)

        // Fetch credentials from Remote Config with fallback for initial launch
        // TODO: SECURITY - These fallback credentials were exposed in git history and should be rotated.
        // After adding new credentials to Firebase Remote Config (privy_app_id, privy_app_client_id),
        // rotate the old credentials in the Privy dashboard.
        let remoteConfig = RemoteConfigManager.shared
        let appId = remoteConfig.privyAppId.isEmpty ? "cmk4fhejw03mnjz0d06pz1v8q" : remoteConfig.privyAppId
        let clientId = remoteConfig.privyAppClientId.isEmpty ? "client-WY6UwitVHyhdeodPopGmp1QCgJ1ppxMyaZ9ZPBYauAA5s" : remoteConfig.privyAppClientId

        let config = PrivyConfig(
            appId: appId,
            appClientId: clientId,
            loggingConfig: loggingConfig
        )

        privyClient = PrivySdk.initialize(config: config)
        logger.debug("Privy SDK initialized")
    }

    // MARK: - Authentication

    /// Authenticate with Privy OAuth (Apple), then bridge to Firebase
    func authenticateWithPrivyOAuth() async throws {
        try await authenticateWithProvider(PrivySDK.OAuthProvider.apple)
    }

    /// Authenticate with Privy OAuth (Google), then bridge to Firebase
    func authenticateWithPrivyGoogle() async throws {
        try await authenticateWithProvider(PrivySDK.OAuthProvider.google)
    }

    /// Generic OAuth authentication with any provider
    private func authenticateWithProvider(_ provider: PrivySDK.OAuthProvider) async throws {
        logger.debug("Starting Privy OAuth Sign-In...")

        guard let privy = privyClient else {
            throw HybridPrivyError.authenticationFailed("Privy client not initialized")
        }

        do {
            let privyUser = try await privy.oAuth.login(with: provider, appUrlScheme: "mimic")
            logger.debug("Privy authentication successful")

            // Continue with the rest of authentication
            try await handleSuccessfulAuth(privyUser: privyUser)
        } catch {
            logger.error("Privy OAuth login failed: \(error.localizedDescription)")

            throw error
        }
    }

    private func handleSuccessfulAuth(privyUser: PrivyUser) async throws {
        logger.debug("Privy authentication successful")

        // Extract email from linked accounts
        for account in privyUser.linkedAccounts {
            if case .email(let emailAccount) = account {
                self.authenticatedEmail = emailAccount.email
                break
            }
            if case .apple(let appleAccount) = account {
                self.authenticatedEmail = appleAccount.email
                break
            }
            if case .google(let googleAccount) = account {
                self.authenticatedEmail = googleAccount.email
                break
            }
        }

        // Bridge to Firebase and get the Firebase UID
        let firebaseUid = try await bridgeToFirebase(privyUser: privyUser)

        // Fetch user data and wallet, passing the Firebase UID for Firestore queries
        await fetchUserData(privyUser: privyUser, firebaseUid: firebaseUid)
    }

    // MARK: - Firebase Bridge

    /// Bridge Privy authentication to Firebase by creating a custom token
    @discardableResult
    private func bridgeToFirebase(privyUser: PrivyUser) async throws -> String {
        logger.debug("Bridging to Firebase...")

        do {
            // Prepare user data for Firebase bridge
            var privyUserData: [String: Any] = [:]

            // Determine authentication method
            let authMethod = "privy_apple"

            // Include email if available (Apple Sign-In)
            if let email = self.authenticatedEmail {
                privyUserData["email"] = email
                logger.debug("Including email in Firebase bridge")
            }

            // Extract displayName and wallet from linked accounts if available
            var displayName: String? = nil
            var address: String? = nil

            for account in privyUser.linkedAccounts {
                switch account {
                case .email(let emailAcc):
                    displayName = displayName ?? emailAcc.email
                case .embeddedSolanaWallet(let sol):
                    address = sol.address
                default:
                    break
                }
            }

            if let displayName { privyUserData["displayName"] = displayName }
            if let address {
                privyUserData["wallet"] = ["address": address]
                logger.debug("Including wallet in Firebase bridge")
            }

            // Create Firebase custom token using the Privy user
            let result = try await firebaseCallable.call(
                "createFirebaseCustomToken",
                data: [
                    "authMethod": authMethod,
                    "privyUserId": privyUser.id,
                    "privyUserData": privyUserData,
                    "timestamp": Date().timeIntervalSince1970
                ]
            )

            guard let data = result.data as? [String: Any],
                  let customToken = data["customToken"] as? String else {
                throw HybridPrivyError.authenticationFailed("Failed to create Firebase token")
            }

            // Sign in to Firebase with custom token
            let authResult = try await Auth.auth().signIn(withCustomToken: customToken)

            logger.debug("Firebase authentication successful")

            // Return the Firebase UID for use in Firestore queries
            return authResult.user.uid

        } catch {
            logger.error("Firebase bridge failed: \(error.localizedDescription)")
            throw HybridPrivyError.authenticationFailed("Firebase bridge failed: \(error.localizedDescription)")
        }
    }

    // MARK: - User Data

    private func fetchUserData(privyUser: PrivyUser, firebaseUid: String? = nil) async {
        // Get or create Solana wallet
        var wallet: String? = nil

        // Get Privy user ID (this is what we need for API lookups)
        let privyUserId = privyUser.id
        logger.debug("Fetching user data...")

        // First check if user already has a Solana wallet
        for account in privyUser.linkedAccounts {
            if case .embeddedSolanaWallet(let sol) = account {
                wallet = sol.address
                logger.debug("Found existing Solana wallet")
                break
            }
        }

        // If no wallet exists, create one SERVER-SIDE with authorization key
        // This enables auto-convert functionality since Swift SDK doesn't support addSessionSigner
        if wallet == nil {
            do {
                logger.debug("Creating new Solana wallet...")
                let result = try await firebaseCallable.call(
                    "createServerWallet",
                    data: ["privyUserId": privyUserId]
                )

                if let data = result.data as? [String: Any],
                   let walletAddress = data["walletAddress"] as? String {
                    wallet = walletAddress
                    _ = data["hasAuthKey"] as? Bool ?? false
                    _ = data["alreadyExisted"] as? Bool ?? false
                    logger.debug("Server wallet created")
                } else {
                    logger.error("Server wallet creation returned no address")
                }
            } catch {
                logger.error("Failed to create server wallet: \(error.localizedDescription)")
                // Fallback to client-side creation (won't have auth key for auto-convert)
                do {
                    logger.debug("Falling back to client-side wallet creation...")
                    let solanaWallet = try await privyUser.createSolanaWallet()
                    wallet = solanaWallet.address
                    logger.debug("Created client-side wallet")
                } catch {
                    logger.error("Client-side wallet creation failed: \(error.localizedDescription)")
                }
            }
        }

        // Use Firebase UID for Firestore queries, fall back to Privy ID if not available
        let userId = firebaseUid ?? {
            // If we don't have Firebase UID, construct it the same way the Cloud Function does
            let privyId = privyUser.id
            return privyId.starts(with: "privy_") ? privyId : "privy_\(privyId)"
        }()

        // CRITICAL: Update Firestore with wallet address AND Privy user ID
        // The privyUserId is required for Privy API lookups (auto-convert)
        // This ensures both are persisted in the database for use by Cloud Functions
        if let wallet = wallet {
            do {
                let db = Firestore.firestore()
                let userData: [String: Any] = [
                    "walletAddress": wallet,
                    "privyUserId": privyUserId as NSObject,
                    "updatedAt": Date()
                ]

                try await db.collection("users").document(userId).setData(userData, merge: true)
                logger.debug("Updated Firestore with wallet")
            } catch {
                logger.error("Failed to update wallet in Firestore: \(error.localizedDescription)")
                // Don't throw - this is not a fatal error, continue with auth
            }
        }

        await MainActor.run {
            self.isAuthenticated = true
            self.currentUser = User(
                id: userId,  // Use Firebase UID instead of Privy ID
                email: self.authenticatedEmail,
                name: nil,
                walletAddress: wallet
            )
            self.walletAddress = wallet
        }

        logger.debug("User data fetched successfully")
    }

    // MARK: - Sign Out

    func signOut() async throws {
        logger.debug("Signing out...")

        // Get current user and sign out from Privy
        if let user = await privyClient?.getUser() {
            await user.logout()
        }

        // Sign out from Firebase
        try Auth.auth().signOut()

        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
            self.walletAddress = nil
            self.authenticatedEmail = nil
        }

        logger.debug("Signed out successfully")
    }

    // MARK: - Privy Access

    /// Get the current Privy user for signing transactions
    func getPrivyUser() async throws -> PrivyUser? {
        guard let privy = privyClient else {
            logger.error("Privy client not initialized")
            return nil
        }

        return await privy.getUser()
    }

    /// Sign a message for sponsored transactions using Privy embedded wallet
    /// This triggers user approval in the Privy UI
    func signMessageForSponsorship(_ message: String) async throws -> (signature: String, walletAddress: String) {
        guard let privy = privyClient else {
            logger.error("Privy client not initialized")
            throw HybridPrivyError.authenticationFailed("Privy not initialized")
        }

        guard case .authenticated(let privyUser) = await privy.getAuthState() else {
            logger.error("User not authenticated")
            throw HybridPrivyError.authenticationFailed("User not authenticated")
        }

        logger.debug("Getting Solana wallet for signing...")

        // Get the embedded Solana wallets
        let solanaWallets = privyUser.embeddedSolanaWallets
        guard let wallet = solanaWallets.first else {
            logger.error("No Solana wallet found")
            throw HybridPrivyError.authenticationFailed("No Solana wallet found")
        }

        logger.debug("Requesting signature from Privy...")

        // Get the provider and sign the message
        // This will trigger the Privy UI for user approval
        let provider = wallet.provider
        let signature = try await provider.signMessage(message: message)

        logger.debug("Message signed successfully")

        return (signature: signature, walletAddress: wallet.address)
    }

    // MARK: - Helpers

    func isUserAuthenticated() async -> Bool {
        // Check both Privy and Firebase authentication status
        let authState = await privyClient?.getAuthState()
        if case .authenticated = authState {
            // Restore user data from Privy if session exists
            if let privyUser = await privyClient?.getUser() {
                // Check Firebase authentication status
                if let currentUser = Auth.auth().currentUser {
                    logger.debug("Firebase session exists - validating...")
                    do {
                        // First try to get token WITHOUT forcing refresh
                        // Firebase SDK will auto-refresh if needed (much faster)
                        let tokenResult = try await currentUser.getIDTokenResult(forcingRefresh: false)
                        logger.debug("Firebase session is valid")
                        
                        // Check token expiration - refresh proactively if expiring soon (within 5 minutes)
                        let expirationTime = tokenResult.expirationDate.timeIntervalSinceNow
                        if expirationTime < 300 { // Less than 5 minutes remaining
                            logger.debug("Token expiring soon, refreshing...")
                            _ = try await currentUser.getIDTokenResult(forcingRefresh: true)
                            logger.debug("Firebase token refreshed")
                        }

                        // Get Firebase UID for Firestore queries
                        let firebaseUid = currentUser.uid
                        await fetchUserData(privyUser: privyUser, firebaseUid: firebaseUid)
                    } catch {
                        // Token refresh failed, try forcing a refresh
                        logger.debug("Auto-refresh failed, attempting manual refresh...")
                        do {
                            _ = try await currentUser.getIDTokenResult(forcingRefresh: true)
                            logger.debug("Firebase token manually refreshed")

                            // Get Firebase UID for Firestore queries
                            let firebaseUid = currentUser.uid
                            await fetchUserData(privyUser: privyUser, firebaseUid: firebaseUid)
                        } catch {
                            // Both auto and manual refresh failed, re-authenticate
                            logger.debug("Token refresh failed - re-authenticating...")
                            do {
                                let firebaseUid = try await bridgeToFirebase(privyUser: privyUser)
                                await fetchUserData(privyUser: privyUser, firebaseUid: firebaseUid)
                            } catch {
                                logger.error("Failed to re-authenticate with Firebase")
                                return false
                            }
                        }
                    }
                } else {
                    // No Firebase session, need to authenticate
                    logger.debug("No Firebase session - authenticating...")
                    do {
                        let firebaseUid = try await bridgeToFirebase(privyUser: privyUser)
                        await fetchUserData(privyUser: privyUser, firebaseUid: firebaseUid)
                    } catch {
                        logger.error("Failed to authenticate with Firebase")
                        return false
                    }
                }
            }
            return Auth.auth().currentUser != nil
        }
        return false
    }
}

// MARK: - Errors

enum HybridPrivyError: LocalizedError {
    case invalidCredential
    case missingToken
    case authenticationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple ID credential"
        case .missingToken:
            return "Missing identity token"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        }
    }
}
