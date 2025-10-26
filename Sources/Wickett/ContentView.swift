import SwiftUI

struct ContentView: View {
    @StateObject private var authCoordinator = AuthCoordinator.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var notificationManager = NotificationManager.shared

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isInitializing = true

    var body: some View {
        Group {
            if isInitializing {
                VStack {
                    LoadingView(message: "Loading Wickett...")
                        .padding(.top, 100)
                    Spacer()
                }
            } else if authCoordinator.isLoading {
                VStack {
                    LoadingView(message: "Authenticating with Privy & bridging to Firebase...")
                        .padding(.top, 100)
                    Spacer()
                }
            } else if !authCoordinator.isAuthenticated {
                LoginView(
                    onAppleSignIn: signInWithApple,
                    onGoogleSignIn: signInWithGoogle
                )
            } else if let user = authCoordinator.currentUser {
                // Check if user needs to complete onboarding
                if !onboardingManager.hasCompletedOnboarding {
                    OnboardingCoordinatorView()
                        .environmentObject(onboardingManager)
                        .environmentObject(themeManager)
                        .environmentObject(notificationManager)
                        .environmentObject(authCoordinator)
                } else {
                    // Show main app with tab navigation
                    MainTabView(
                        user: user,
                        onSignOut: signOut
                    )
                    .environmentObject(onboardingManager)
                    .environmentObject(themeManager)
                    .environmentObject(notificationManager)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .preferredColorScheme(themeManager.colorScheme)
        .onAppear {
            checkAuthenticationStatus()
        }
    }

    // MARK: - Authentication Actions

    private func signInWithApple() async {
        do {
            try await authCoordinator.signInWithPrivyOAuth()

            // Check onboarding status after successful sign-in
            if let userId = authCoordinator.currentUser?.id {
                await onboardingManager.checkOnboardingStatus(userId: userId)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Apple Sign in failed: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }

    private func signInWithGoogle() async {
        do {
            try await authCoordinator.signInWithPrivyGoogle()

            // Check onboarding status after successful sign-in
            if let userId = authCoordinator.currentUser?.id {
                print("🎯 ContentView: Checking onboarding status for user: \(userId)")
                await onboardingManager.checkOnboardingStatus(userId: userId)
                print("🎯 ContentView: Onboarding check complete. hasCompletedOnboarding = \(onboardingManager.hasCompletedOnboarding)")
            } else {
                print("⚠️ ContentView: No userId found after sign-in")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Google Sign in failed: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }

    private func checkAuthenticationStatus() {
        Task {
            await authCoordinator.checkAuthenticationStatus()

            // If authenticated, check onboarding status
            if authCoordinator.isAuthenticated, let userId = authCoordinator.currentUser?.id {
                await onboardingManager.checkOnboardingStatus(userId: userId)
            }

            // Initialization complete - safe to show content
            await MainActor.run {
                isInitializing = false
            }
        }
    }

    private func signOut() async {
        do {
            try await authCoordinator.signOut()

            // Reset onboarding state when signing out
            await MainActor.run {
                onboardingManager.resetOnboarding()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Sign out failed: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
