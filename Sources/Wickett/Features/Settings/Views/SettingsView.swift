import SwiftUI
import FirebaseFirestore
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Wickett", category: "SettingsView")

struct SettingsView: View {
    let user: User
    let onDismiss: () -> Void
    let onSignOut: () async -> Void

    private let db = Firestore.firestore()

    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var savedUsername: String? = nil // Tracks saved username for UI refresh
    @State private var isEditingUsername = false
    @State private var isSavingUsername = false
    @State private var usernameError: String?
    @State private var notificationsEnabled = false
    @State private var selectedTheme: AppTheme = .system
    @State private var degenModeEnabled = false
    @State private var showingDegenModeWarning = false
    @State private var showingWalkthrough = false
    @State private var showingSignOutConfirmation = false
    @State private var showingDevContactAlert = false
    @State private var devContactMessage = ""
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingDeleteAccountError = false
    @State private var deleteAccountErrorMessage = ""
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationView {
            Form {
                    // Profile Section
                    Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(BrandColors.primary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName.isEmpty ? user.displayName : displayName)
                                .font(.headline)
                            if let email = user.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)

                    HStack {
                        Text("Display Name")
                        Spacer()
                        TextField("Name", text: $displayName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }

                    // Username field
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Username")
                            Spacer()
                            if isSavingUsername {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let existing = savedUsername ?? user.username {
                                Text("@\(existing)")
                                    .foregroundColor(.secondary)
                            } else {
                                HStack(spacing: 4) {
                                    Text("@")
                                        .foregroundColor(.secondary)
                                    TextField("username", text: $username)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .multilineTextAlignment(.trailing)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if let error = usernameError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        if savedUsername == nil && user.username == nil && !username.isEmpty {
                            Button(action: saveUsername) {
                                Text("Save Username")
                                    .font(.subheadline)
                                    .foregroundColor(BrandColors.primary)
                            }
                            .disabled(isSavingUsername)
                        }
                    }
                } header: {
                    Text("Profile")
                } footer: {
                    if savedUsername == nil && user.username == nil {
                        Text("Set a username so others can find you by @username")
                    }
                }

                // Preferences Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(BrandColors.primary)
                            Text("Notifications")
                        }
                    }
                    .onChange(of: notificationsEnabled) { newValue in
                        handleNotificationToggle(newValue)
                    }

                    Picker(selection: $selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            HStack {
                                Image(systemName: themeIcon(for: theme))
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(BrandColors.primary)
                            Text("Theme")
                        }
                    }
                    .onChange(of: selectedTheme) { newValue in
                        themeManager.setTheme(newValue)
                    }

                } header: {
                    Text("Preferences")
                }

                // Trading Mode Section (Mimic)
                Section {
                    Toggle(isOn: Binding(
                        get: { degenModeEnabled },
                        set: { newValue in
                            if newValue {
                                showingDegenModeWarning = true
                            } else {
                                degenModeEnabled = false
                                saveDegenModeSetting(false)
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Degen Mode")
                                    .foregroundColor(.primary)
                                Text("Copy trades on any token")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(.orange)

                    if !degenModeEnabled {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Safe Mode Active")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                Text("Only major tokens (SOL, USDC, ETH, etc.)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("All Tokens Unlocked")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                Text("Including memecoins & pumpfun tokens")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Trading Mode")
                } footer: {
                    Text("Degen Mode allows copying trades on any token, including high-risk memecoins. Safe Mode only allows established tokens.")
                }

                // Help & Support Section
                Section {
                    Button(action: {
                        addDevContact()
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(BrandColors.primary)
                            Text("Add Wickett Team Contact")
                        }
                    }

                    Button(action: {
                        showingWalkthrough = true
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(BrandColors.primary)
                            Text("Replay Tutorial")
                        }
                    }

                    Link(destination: URL(string: AppConfiguration.Legal.termsOfServiceURL)!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(BrandColors.primary)
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }

                    Link(destination: URL(string: AppConfiguration.Legal.privacyPolicyURL)!) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(BrandColors.primary)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }

                    Link(destination: URL(string: AppConfiguration.Legal.supportURL)!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(BrandColors.primary)
                            Text("Support")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Help & Support")
                }

                // Account Section
                Section {
                    Button(role: .destructive, action: {
                        showingSignOutConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.left.circle.fill")
                            Text("Sign Out")
                        }
                    }

                    Button(role: .destructive, action: {
                        showingDeleteAccountConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Account")
                            if isDeletingAccount {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isDeletingAccount)
                } header: {
                    Text("Account")
                }

                // App Info Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // Developer Section (for testing)
                #if DEBUG
                Section {
                    Button(action: {
                        onboardingManager.resetOnboarding()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.orange)
                            Text("Reset Onboarding")
                        }
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Resets onboarding state to test the onboarding flow again")
                }
                #endif
                
                // Spacer for custom tab bar
                Section {
                    Color.clear
                        .frame(height: 60)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadPreferences()
                loadDegenModeSetting()
            }
            .onChange(of: displayName) { _ in
                savePreferences()
            }
            .onChange(of: selectedTheme) { _ in
                savePreferences()
            }
            .onChange(of: notificationsEnabled) { _ in
                savePreferences()
            }
            .sheet(isPresented: $showingWalkthrough) {
                WalkthroughView(
                    onContinue: {
                        showingWalkthrough = false
                    },
                    onBack: {
                        showingWalkthrough = false
                    }
                )
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        await onSignOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Add Contact", isPresented: $showingDevContactAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(devContactMessage)
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Forever", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account, wallet, and all data. This action cannot be undone.\n\nMake sure to transfer any remaining funds first!")
            }
            .alert("Error", isPresented: $showingDeleteAccountError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteAccountErrorMessage)
            }
            .alert("Enable Degen Mode?", isPresented: $showingDegenModeWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Enable", role: .destructive) {
                    degenModeEnabled = true
                    saveDegenModeSetting(true)
                }
            } message: {
                Text("Degen Mode unlocks ALL tokens including high-risk memecoins and pumpfun tokens.\n\n⚠️ Most copy traders lose money on memecoins. Only enable if you understand the risks.")
            }
        }
    }

    // MARK: - Computed Properties

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Helpers

    private func saveUsername() {
        guard !username.isEmpty else { return }

        isSavingUsername = true
        usernameError = nil

        Task {
            do {
                let confirmedUsername = try await UsernameService.shared.updateUsername(username: username)

                // Refresh user data so username persists across views
                await AuthCoordinator.shared.fetchUserData()

                await MainActor.run {
                    isSavingUsername = false
                    savedUsername = confirmedUsername
                    username = "" // Clear input field
                    logger.info("✅ Username saved: @\(confirmedUsername)")
                }
            } catch {
                await MainActor.run {
                    isSavingUsername = false
                    usernameError = error.localizedDescription
                }
                logger.error("❌ Failed to save username: \(error.localizedDescription)")
            }
        }
    }

    private func addDevContact() {
        Task {
            do {
                let firebaseClient = FirebaseCallableClient.shared

                // First, setup the Wickett Team user document with username for search
                _ = try? await firebaseClient.call("setupWickettTeamUser", data: [:])

                // Then add as contact for the current user
                let result = try await firebaseClient.call("addDevContact", data: [
                    "walletAddress": "74tDwBrYudu642jnpqtfvkNpxUxiX2RVJ76jW2Ut8hUA",
                    "displayName": "Wickett Team",
                    "username": "wickettteam"
                ])

                if let response = result.data as? [String: Any],
                   let success = response["success"] as? Bool,
                   success {
                    await MainActor.run {
                        devContactMessage = "✅ Wickett Team contact added successfully! You can now search for @wickettteam."
                        showingDevContactAlert = true
                    }
                    logger.info("✅ Dev contact added successfully")
                } else {
                    await MainActor.run {
                        devContactMessage = "❌ Failed to add contact. Please try again."
                        showingDevContactAlert = true
                    }
                    logger.error("Failed to add dev contact")
                }
            } catch {
                await MainActor.run {
                    devContactMessage = "❌ Error: \(error.localizedDescription)"
                    showingDevContactAlert = true
                }
                logger.error("Error adding dev contact: \(error.localizedDescription)")
            }
        }
    }

    private func themeIcon(for theme: AppTheme) -> String {
        switch theme {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "gear"
        }
    }

    private func loadPreferences() {
        // Load from theme manager
        selectedTheme = themeManager.currentTheme

        // Load from notification manager
        notificationsEnabled = notificationManager.isAuthorized

        // Display name from user or onboarding state
        displayName = user.name ?? ""
    }

    private func savePreferences() {
        // Update preferences in onboarding manager (for in-memory state)
        var preferences = onboardingManager.onboardingState.preferences
        preferences.notificationsEnabled = notificationsEnabled
        preferences.theme = selectedTheme
        preferences.updatedAt = Date()

        onboardingManager.updatePreferences(preferences)

        // Update display name if changed
        if !displayName.isEmpty && displayName != user.name {
            onboardingManager.updateDisplayName(displayName)
        }

        // Save to Firestore directly (don't re-complete onboarding)
        if let userId = user.id as String? {
            Task {
                do {
                    try await db.collection("users").document(userId).setData([
                        "displayName": displayName.isEmpty ? user.displayName : displayName,
                        "preferences": preferences.toDictionary(),
                        "updatedAt": Date()
                    ], merge: true)
                    logger.info("✅ Saved preferences to Firestore")
                } catch {
                    logger.error("❌ Failed to save preferences: \(error)")
                }
            }
        }
    }

    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            Task {
                do {
                    try await notificationManager.enableNotifications()
                    notificationsEnabled = notificationManager.isAuthorized
                } catch {
                    notificationsEnabled = false
                }
            }
        }
    }

    private func saveDegenModeSetting(_ enabled: Bool) {
        guard let userId = user.id as String? else { return }

        Task {
            do {
                try await db.collection("users").document(userId).setData([
                    "preferences": [
                        "degenMode": enabled
                    ],
                    "updatedAt": Date()
                ], merge: true)
                logger.info("✅ Degen mode \(enabled ? "enabled" : "disabled")")
            } catch {
                logger.error("❌ Failed to save degen mode setting: \(error)")
            }
        }
    }

    private func loadDegenModeSetting() {
        guard let userId = user.id as String? else { return }

        Task {
            do {
                let doc = try await db.collection("users").document(userId).getDocument()
                if let prefs = doc.data()?["preferences"] as? [String: Any],
                   let degenMode = prefs["degenMode"] as? Bool {
                    await MainActor.run {
                        degenModeEnabled = degenMode
                    }
                }
            } catch {
                logger.error("Failed to load degen mode setting: \(error)")
            }
        }
    }

    private func deleteAccount() async {
        await MainActor.run {
            isDeletingAccount = true
        }

        do {
            let firebaseClient = FirebaseCallableClient.shared
            let result = try await firebaseClient.call("deleteUserAccount", data: [:])

            let response = result.data as? [String: Any]
            let success = response?["success"] as? Bool ?? false

            if success {
                logger.info("✅ Account deleted successfully")

                // Clear local state
                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                UserDefaults.standard.removeObject(forKey: "onboardingState")

                // Reset onboarding state
                await MainActor.run {
                    onboardingManager.resetOnboarding()
                }

                // Sign out (this will navigate to login)
                await onSignOut()
            } else {
                let message = (response?["message"] as? String) ?? "Unknown error"
                await MainActor.run {
                    isDeletingAccount = false
                    deleteAccountErrorMessage = "Failed to delete account: \(message)"
                    showingDeleteAccountError = true
                }
            }
        } catch {
            logger.error("❌ Error deleting account: \(error.localizedDescription)")
            await MainActor.run {
                isDeletingAccount = false
                deleteAccountErrorMessage = "Error: \(error.localizedDescription)"
                showingDeleteAccountError = true
            }
        }
    }
}

#Preview {
    SettingsView(
        user: User(
            id: "test",
            email: "test@example.com",
            name: "Test User",
            walletAddress: "ABC123XYZ789ABC123XYZ789", username: nil
        ),
        onDismiss: {},
        onSignOut: {}
    )
    .environmentObject(OnboardingManager.shared)
    .environmentObject(ThemeManager.shared)
    .environmentObject(NotificationManager.shared)
}
