import SwiftUI

/// View for adding a new wallet to track
struct AddWalletView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var trackingService = TrackingService.shared

    @State private var walletAddress = ""
    @State private var nickname = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    @FocusState private var isAddressFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 48))
                        .foregroundColor(BrandColors.primary)

                    Text("Track a Wallet")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter a Solana wallet address to track their trades")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Input Fields
                VStack(spacing: 16) {
                    // Wallet Address
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wallet Address")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Enter Solana address...", text: $walletAddress)
                            .font(.system(.body, design: .monospaced))
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .focused($isAddressFocused)

                        // Paste button
                        if walletAddress.isEmpty {
                            Button(action: pasteFromClipboard) {
                                HStack {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste from clipboard")
                                }
                                .font(.subheadline)
                                .foregroundColor(BrandColors.primary)
                            }
                        }
                    }

                    // Nickname (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Nickname")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("(optional)")
                                .font(.caption)
                                .foregroundColor(.tertiary)
                        }

                        TextField("e.g. Whale Trader, Smart Money", text: $nickname)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                // Error Message
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Wallet Limit Info
                walletLimitInfo
                    .padding(.horizontal)

                Spacer()

                // Add Button
                Button(action: addWallet) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Track Wallet")
                        }
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isValidAddress
                        ? BrandColors.primaryGradient
                        : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
                .disabled(!isValidAddress || isLoading)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Add Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isAddressFocused = true
            }
            .alert("Wallet Added!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("You'll receive notifications when this wallet makes trades.")
            }
        }
    }

    // MARK: - Wallet Limit Info

    private var walletLimitInfo: some View {
        let currentCount = trackingService.trackedWallets.count
        let maxCount = 3 // Free tier limit

        return HStack {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)

            Text("\(currentCount)/\(maxCount) wallets tracked")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if currentCount >= maxCount {
                Text("Upgrade to Pro for more")
                    .font(.caption)
                    .foregroundColor(BrandColors.primary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Validation

    private var isValidAddress: Bool {
        // Basic Solana address validation (base58, 32-44 chars)
        let regex = "^[1-9A-HJ-NP-Za-km-z]{32,44}$"
        return walletAddress.range(of: regex, options: .regularExpression) != nil
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        if let clipboardContent = UIPasteboard.general.string {
            walletAddress = clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func addWallet() {
        guard isValidAddress else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                _ = try await trackingService.addTrackedWallet(
                    address: walletAddress,
                    nickname: nickname.isEmpty ? nil : nickname
                )
                showSuccess = true
            } catch let error as TrackingError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Failed to add wallet. Please try again."
            }

            isLoading = false
        }
    }
}

#Preview {
    AddWalletView()
        .environmentObject(ThemeManager.shared)
}
