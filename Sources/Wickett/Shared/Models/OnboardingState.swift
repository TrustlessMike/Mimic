import Foundation

/// Onboarding step enumeration (streamlined flow)
enum OnboardingStep: Int, Codable, CaseIterable {
    case welcome = 0
    case testingInfo = 1
    case profile = 2
    case notifications = 3

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .testingInfo: return "Testing Guide"
        case .profile: return "Set Up Profile"
        case .notifications: return "Notifications"
        }
    }

    var next: OnboardingStep? {
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: self),
              currentIndex + 1 < allSteps.count else {
            return nil
        }
        return allSteps[currentIndex + 1]
    }

    var previous: OnboardingStep? {
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: self),
              currentIndex > 0 else {
            return nil
        }
        return allSteps[currentIndex - 1]
    }
}

/// State tracking for onboarding flow
struct OnboardingState {
    var currentStep: OnboardingStep
    var displayName: String
    var username: String?
    var preferences: UserPreferences
    var hasAcceptedTerms: Bool

    init(
        currentStep: OnboardingStep = .welcome,
        displayName: String = "",
        username: String? = nil,
        preferences: UserPreferences = UserPreferences(),
        hasAcceptedTerms: Bool = false
    ) {
        self.currentStep = currentStep
        self.displayName = displayName
        self.username = username
        self.preferences = preferences
        self.hasAcceptedTerms = hasAcceptedTerms
    }

    /// Profile is complete when display name and username are set, and terms accepted
    var isComplete: Bool {
        return !displayName.isEmpty && username != nil && !username!.isEmpty && hasAcceptedTerms
    }

    var progress: Double {
        let totalSteps = Double(OnboardingStep.allCases.count)
        let currentStepIndex = Double(currentStep.rawValue + 1)
        return currentStepIndex / totalSteps
    }
}
