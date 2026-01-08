import SwiftUI
import FirebaseFirestore
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "SettingsView")

struct SettingsView: View {
    let user: User
    let onDismiss: () -> Void
    let onSignOut: () async -> Void

    private let db = Firestore.firestore()

    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var displayName: String = ""
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

    // Copy Trading State
    @StateObject private var copyService = CopyTradingService.shared
    @State private var showingTrackedWallets = false
    @State private var copyPercentage: Double = 0.05
    @State private var maxCopyAmount: Double = 50.0
    @State private var dailyLimit: Double = 200.0

    var body: some View {
        NavigationView {
            Form {
                    // Profile Section
                    Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: IconSize.xxl + 12))
                            .foregroundColor(BrandColors.primary)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(displayName.isEmpty ? user.displayName : displayName)
                                .font(Typography.headlineSmall)
                                .foregroundColor(SemanticColors.textPrimary)
                            if let email = user.email {
                                Text(email)
                                    .font(Typography.bodyMedium)
                                    .foregroundColor(SemanticColors.textSecondary)
                            }
                        }
                        .padding(.leading, Spacing.sm)
                    }
                    .padding(.vertical, Spacing.sm)

                    HStack {
                        Text("Display Name")
                            .foregroundColor(SemanticColors.textPrimary)
                        Spacer()
                        TextField("Name", text: $displayName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(SemanticColors.textSecondary)
                    }
                } header: {
                    Text("Profile")
                }

                // Preferences Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(BrandColors.primary)
                            Text("Notifications")
                                .foregroundColor(SemanticColors.textPrimary)
                        }
                    }
                    .onChange(of: notificationsEnabled) { _, newValue in
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
                                .foregroundColor(SemanticColors.textPrimary)
                        }
                    }
                    .onChange(of: selectedTheme) { _, newValue in
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
                                .foregroundColor(SemanticColors.warning)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Degen Mode")
                                    .foregroundColor(SemanticColors.textPrimary)
                                Text("Copy trades on any token")
                                    .font(Typography.labelSmall)
                                    .foregroundColor(SemanticColors.textSecondary)
                            }
                        }
                    }
                    .tint(SemanticColors.warning)

                    if !degenModeEnabled {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(SemanticColors.success)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Safe Mode Active")
                                    .font(Typography.bodyMedium)
                                    .foregroundColor(SemanticColors.success)
                                Text("Only major tokens (SOL, USDC, ETH, etc.)")
                                    .font(Typography.labelSmall)
                                    .foregroundColor(SemanticColors.textSecondary)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(SemanticColors.warning)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("All Tokens Unlocked")
                                    .font(Typography.bodyMedium)
                                    .foregroundColor(SemanticColors.warning)
                                Text("Including memecoins & pumpfun tokens")
                                    .font(Typography.labelSmall)
                                    .foregroundColor(SemanticColors.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("Trading Mode")
                } footer: {
                    Text("Degen Mode allows copying trades on any token, including high-risk memecoins. Safe Mode only allows established tokens.")
                }

                // Copy Trading Section
                Section {
                    // Tracked Wallets
                    Button(action: { showingTrackedWallets = true }) {
                        HStack {
                            Image(systemName: "doc.on.doc.fill")
                                .foregroundColor(BrandColors.primary)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Tracked Wallets")
                                    .foregroundColor(SemanticColors.textPrimary)
                                Text("\(copyService.trackedWallets.count) wallet\(copyService.trackedWallets.count == 1 ? "" : "s")")
                                    .font(Typography.labelSmall)
                                    .foregroundColor(SemanticColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(SemanticColors.textSecondary)
                                .font(Typography.labelSmall)
                        }
                    }

                    // Copy Percentage
                    HStack {
                        Image(systemName: "percent")
                            .foregroundColor(BrandColors.primary)
                        Text("Copy Size")
                            .foregroundColor(SemanticColors.textPrimary)
                        Spacer()
                        Picker("", selection: $copyPercentage) {
                            Text("1%").tag(0.01)
                            Text("2%").tag(0.02)
                            Text("5%").tag(0.05)
                            Text("10%").tag(0.10)
                        }
                        .pickerStyle(.menu)
                    }
                    .onChange(of: copyPercentage) {
                        saveCopySettings()
                    }

                    // Max Per Trade
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(BrandColors.primary)
                        Text("Max Per Trade")
                            .foregroundColor(SemanticColors.textPrimary)
                        Spacer()
                        Picker("", selection: $maxCopyAmount) {
                            Text("$25").tag(25.0)
                            Text("$50").tag(50.0)
                            Text("$100").tag(100.0)
                            Text("$250").tag(250.0)
                        }
                        .pickerStyle(.menu)
                    }
                    .onChange(of: maxCopyAmount) {
                        saveCopySettings()
                    }

                    // Daily Limit
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(BrandColors.primary)
                        Text("Daily Limit")
                            .foregroundColor(SemanticColors.textPrimary)
                        Spacer()
                        Picker("", selection: $dailyLimit) {
                            Text("$100").tag(100.0)
                            Text("$200").tag(200.0)
                            Text("$500").tag(500.0)
                            Text("$1000").tag(1000.0)
                        }
                        .pickerStyle(.menu)
                    }
                    .onChange(of: dailyLimit) {
                        saveCopySettings()
                    }
                } header: {
                    Text("Copy Trading")
                } footer: {
                    Text("Configure how much to invest when copying trades. Your \(degenModeEnabled ? "Degen" : "Safe") Mode setting above controls which tokens can be copied.")
                }

                // Help & Support Section
                Section {
                    Button(action: {
                        addDevContact()
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(BrandColors.primary)
                            Text("Add Mimic Team Contact")
                                .foregroundColor(SemanticColors.textPrimary)
                        }
                    }

                    Button(action: {
                        showingWalkthrough = true
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(BrandColors.primary)
                            Text("Replay Tutorial")
                                .foregroundColor(SemanticColors.textPrimary)
                        }
                    }

                    Link(destination: URL(string: AppConfiguration.Legal.termsOfServiceURL)!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(BrandColors.primary)
                            Text("Terms of Service")
                                .foregroundColor(SemanticColors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(SemanticColors.textSecondary)
                                .font(Typography.labelSmall)
                        }
                    }

                    Link(destination: URL(string: AppConfiguration.Legal.privacyPolicyURL)!) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(BrandColors.primary)
                            Text("Privacy Policy")
                                .foregroundColor(SemanticColors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(SemanticColors.textSecondary)
                                .font(Typography.labelSmall)
                        }
                    }

                    Link(destination: URL(string: AppConfiguration.Legal.supportURL)!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(BrandColors.primary)
                            Text("Support")
                                .foregroundColor(SemanticColors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(SemanticColors.textSecondary)
                                .font(Typography.labelSmall)
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
                            .foregroundColor(SemanticColors.textPrimary)
                        Spacer()
                        Text(appVersionString)
                            .foregroundColor(SemanticColors.textSecondary)
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
                                .foregroundColor(SemanticColors.warning)
                            Text("Reset Onboarding")
                                .foregroundColor(SemanticColors.textPrimary)
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
                loadCopySettings()
            }
            .task {
                await copyService.loadTrackedWallets()
            }
            .onChange(of: displayName) {
                savePreferences()
            }
            .onChange(of: selectedTheme) {
                savePreferences()
            }
            .onChange(of: notificationsEnabled) {
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
            .sheet(isPresented: $showingTrackedWallets) {
                TrackedWalletsView()
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

    private func addDevContact() {
        Task {
            do {
                let firebaseClient = FirebaseCallableClient.shared

                // First, setup the Mimic Team user document
                _ = try? await firebaseClient.call("setupMimicTeamUser", data: [:])

                // Then add as contact for the current user
                let result = try await firebaseClient.call("addDevContact", data: [
                    "walletAddress": "74tDwBrYudu642jnpqtfvkNpxUxiX2RVJ76jW2Ut8hUA",
                    "displayName": "Mimic Team"
                ])

                if let response = result.data as? [String: Any],
                   let success = response["success"] as? Bool,
                   success {
                    await MainActor.run {
                        devContactMessage = "✅ Mimic Team contact added successfully!"
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

        // Display name - use user's name or display name, keeping them in sync
        displayName = user.name ?? user.displayName
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
                    // Always sync toggle state with actual system permission
                    await MainActor.run {
                        notificationsEnabled = notificationManager.isAuthorized
                    }
                } catch {
                    await MainActor.run {
                        notificationsEnabled = false
                    }
                }
            }
        } else {
            // User is disabling - we can't revoke system permission, but we can update our state
            // The actual permission can only be changed in Settings app
            Task {
                await MainActor.run {
                    notificationsEnabled = notificationManager.isAuthorized
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

    private func loadCopySettings() {
        guard let userId = user.id as String? else { return }

        Task {
            do {
                let doc = try await db.collection("users").document(userId).getDocument()
                if let config = doc.data()?["copyTradingConfig"] as? [String: Any] {
                    await MainActor.run {
                        copyPercentage = config["copyPercentage"] as? Double ?? 0.05
                        maxCopyAmount = config["maxCopyAmountUsd"] as? Double ?? 50.0
                        dailyLimit = config["dailyLimitUsd"] as? Double ?? 200.0
                    }
                }
            } catch {
                logger.error("Failed to load copy settings: \(error)")
            }
        }
    }

    private func saveCopySettings() {
        guard let userId = user.id as String? else { return }

        Task {
            do {
                try await db.collection("users").document(userId).setData([
                    "copyTradingConfig": [
                        "copyPercentage": copyPercentage,
                        "maxCopyAmountUsd": maxCopyAmount,
                        "dailyLimitUsd": dailyLimit
                    ],
                    "updatedAt": Date()
                ], merge: true)
            } catch {
                logger.error("Failed to save copy settings: \(error)")
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
            walletAddress: "ABC123XYZ789ABC123XYZ789"
        ),
        onDismiss: {},
        onSignOut: {}
    )
    .environmentObject(OnboardingManager.shared)
    .environmentObject(ThemeManager.shared)
    .environmentObject(NotificationManager.shared)
}
