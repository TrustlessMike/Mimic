import SwiftUI

struct OnboardingCoordinatorView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    @State private var isCompleting = false
    @State private var isSavingProfile = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            // Apply theme color scheme
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            // Current step view
            Group {
                switch onboardingManager.onboardingState.currentStep {
                case .welcome:
                    WelcomeView(onContinue: handleWelcomeContinue)

                case .testingInfo:
                    TestingInfoView(onContinue: {
                        onboardingManager.nextStep()
                    })

                case .profile:
                    ProfileSetupView(
                        displayName: $onboardingManager.onboardingState.displayName,
                        onContinue: handleProfileContinue,
                        onBack: onboardingManager.previousStep
                    )

                case .notifications:
                    NotificationsSetupView(
                        onEnable: handleEnableNotifications,
                        onSkip: handleSkipNotifications
                    )
                }
            }

            // Loading overlay
            if isCompleting || isSavingProfile {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(BrandColors.primary)
                    Text(isSavingProfile ? "Setting up your profile..." : "Finishing setup...")
                        .foregroundColor(.primary)
                        .font(.headline)
                }
                .padding(30)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Step Handlers

    private func handleWelcomeContinue() {
        // Terms are accepted on Welcome screen
        onboardingManager.acceptTerms()
        onboardingManager.nextStep()
    }

    private func handleProfileContinue(username: String) {
        guard !onboardingManager.onboardingState.displayName.isEmpty else { return }
        guard !username.isEmpty else { return }

        isSavingProfile = true

        Task {
            do {
                // Save username to Firebase
                let confirmedUsername = try await UsernameService.shared.updateUsername(username: username)

                await MainActor.run {
                    onboardingManager.updateDisplayName(onboardingManager.onboardingState.displayName)
                    onboardingManager.updateUsername(confirmedUsername)
                    isSavingProfile = false
                    onboardingManager.nextStep()
                }
            } catch {
                await MainActor.run {
                    isSavingProfile = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func handleEnableNotifications() {
        Task {
            do {
                try await notificationManager.enableNotifications()
            } catch {
                // User declined or error - continue anyway
            }
            await finishOnboarding()
        }
    }

    private func handleSkipNotifications() {
        Task {
            await finishOnboarding()
        }
    }

    // MARK: - Completion

    private func finishOnboarding() async {
        guard let userId = authCoordinator.currentUser?.id else {
            await MainActor.run {
                errorMessage = "User not authenticated"
                showError = true
            }
            return
        }

        await MainActor.run {
            isCompleting = true
        }

        do {
            try await onboardingManager.completeOnboarding(userId: userId)

            // Refresh user data to fetch the displayName from Firestore
            await authCoordinator.checkAuthenticationStatus()

            await MainActor.run {
                isCompleting = false
            }
        } catch {
            await MainActor.run {
                isCompleting = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    OnboardingCoordinatorView()
        .environmentObject(OnboardingManager.shared)
        .environmentObject(ThemeManager.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(AuthCoordinator.shared)
}
