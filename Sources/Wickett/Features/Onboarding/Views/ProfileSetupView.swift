import SwiftUI

struct ProfileSetupView: View {
    @Binding var displayName: String
    let onContinue: (String) -> Void
    let onBack: () -> Void

    @ObservedObject private var usernameService = UsernameService.shared
    @State private var username: String = ""
    @State private var isCheckingUsername: Bool = false
    @State private var isUsernameAvailable: Bool? = nil
    @State private var usernameError: String? = nil
    @State private var checkTask: Task<Void, Never>? = nil
    @FocusState private var focusedField: Field?

    enum Field {
        case displayName
        case username
    }

    private var canContinue: Bool {
        !displayName.isEmpty &&
        !username.isEmpty &&
        isUsernameAvailable == true &&
        !isCheckingUsername
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with Back Button and Icon
            VStack(spacing: 24) {
                // Top Bar
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(BrandColors.primary)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)

                // Icon
                ZStack {
                    Circle()
                        .fill(BrandColors.primary.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundColor(BrandColors.primary)
                }
                .padding(.bottom, 8)

                // Title
                VStack(spacing: 12) {
                    Text("Set Up Your Profile")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .tracking(-0.5)

                    Text("Choose how you'll appear to others")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()
                .frame(height: 40)

            // Form fields
            VStack(spacing: 24) {
                // Display Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)

                    TextField("Your name", text: $displayName)
                        .font(.body)
                        .padding()
                        .frame(height: 54)
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                        .focused($focusedField, equals: .displayName)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                        .onChange(of: displayName) { newValue in
                            // Auto-suggest username from display name
                            if username.isEmpty && !newValue.isEmpty {
                                let suggested = newValue.lowercased()
                                    .replacingOccurrences(of: " ", with: "")
                                    .filter { $0.isLetter || $0.isNumber }
                                username = String(suggested.prefix(20))
                            }
                        }
                }

                // Username field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 0) {
                        Text("@")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                            .padding(.trailing, 8)

                        TextField("username", text: $username)
                            .font(.body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .focused($focusedField, equals: .username)
                            .onChange(of: username) { newValue in
                                handleUsernameChange(newValue)
                            }

                        // Status indicator
                        if isCheckingUsername {
                            ProgressView()
                                .padding(.trailing, 16)
                        } else if let available = isUsernameAvailable {
                            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(available ? .green : .red)
                                .padding(.trailing, 16)
                        } else {
                            // Empty spacer to maintain height if needed, 
                            // but in HStack we just let it be.
                        }
                    }
                    .frame(height: 54)
                    .background(Color(.systemGray6))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                usernameError != nil ? Color.red.opacity(0.5) : 
                                (isUsernameAvailable == true ? Color.green.opacity(0.5) : Color.primary.opacity(0.05)), 
                                lineWidth: 1
                            )
                    )

                    // Username status message
                    if let error = usernameError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.leading, 4)
                    } else if isUsernameAvailable == true {
                        Text("@\(usernameService.normalizeUsername(username)) is available")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.leading, 4)
                    } else if username.isEmpty {
                        Text("3-20 characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue Button
            Button(action: {
                let normalizedUsername = usernameService.normalizeUsername(username)
                onContinue(normalizedUsername)
            }) {
                HStack {
                    Text("Continue")
                        .font(.headline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canContinue ? BrandColors.primary : Color(.systemGray5))
                .foregroundColor(canContinue ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear {
            focusedField = .displayName
        }
    }

    // MARK: - Username Handling

    private func handleUsernameChange(_ newValue: String) {
        // Enforce lowercase and remove spaces
        let sanitized = newValue.lowercased().replacingOccurrences(of: " ", with: "")
        if sanitized != newValue {
            username = sanitized
            return
        }

        // Cancel previous check
        checkTask?.cancel()

        // Reset state
        isUsernameAvailable = nil
        usernameError = nil

        // Start new check with debounce
        if !newValue.isEmpty {
            checkTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
                if !Task.isCancelled {
                    await checkUsername(newValue)
                }
            }
        }
    }

    private func checkUsername(_ value: String) async {
        await MainActor.run {
            isCheckingUsername = true
            usernameError = nil
        }

        do {
            let result = try await usernameService.checkAvailability(username: value)

            await MainActor.run {
                isCheckingUsername = false
                isUsernameAvailable = result.available
                if !result.available {
                    usernameError = result.reason
                }
            }
        } catch {
            await MainActor.run {
                isCheckingUsername = false
                isUsernameAvailable = false
                usernameError = error.localizedDescription
            }
        }
    }
}

#Preview {
    ProfileSetupView(
        displayName: .constant(""),
        onContinue: { _ in },
        onBack: {}
    )
}
