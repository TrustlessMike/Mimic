import SwiftUI

struct SettingsView: View {
    let user: User
    let onDismiss: () -> Void
    let onSignOut: () async -> Void

    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var displayName: String = ""
    @State private var notificationsEnabled = false
    @State private var selectedTheme: AppTheme = .system
    @State private var showingWalkthrough = false
    @State private var showingSignOutConfirmation = false

    var body: some View {
        Form {
                // Profile Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

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
                } header: {
                    Text("Profile")
                }

                // Preferences Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
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
                                .foregroundColor(.blue)
                            Text("Theme")
                        }
                    }
                    .onChange(of: selectedTheme) { newValue in
                        themeManager.setTheme(newValue)
                    }
                } header: {
                    Text("Preferences")
                }

                // Help & Support Section
                Section {
                    Button(action: {
                        showingWalkthrough = true
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                            Text("Replay Tutorial")
                        }
                    }

                    Link(destination: URL(string: AppConfiguration.Legal.termsOfServiceURL)!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
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
                                .foregroundColor(.blue)
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
                                .foregroundColor(.blue)
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
                } header: {
                    Text("Account")
                }

                // App Info Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        Text(AppConfiguration.App.bundleId)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("About")
                }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadPreferences()
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
    }

    // MARK: - Helpers

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
        // Update preferences in onboarding manager
        var preferences = onboardingManager.onboardingState.preferences
        preferences.notificationsEnabled = notificationsEnabled
        preferences.theme = selectedTheme
        preferences.updatedAt = Date()

        onboardingManager.updatePreferences(preferences)

        // Update display name if changed
        if !displayName.isEmpty && displayName != user.name {
            onboardingManager.updateDisplayName(displayName)
        }

        // Save to Firestore
        if let userId = user.id as String? {
            Task {
                try? await onboardingManager.completeOnboarding(userId: userId)
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
