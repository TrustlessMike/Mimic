import SwiftUI

/// View for managing tracked wallets and copy trading
struct TrackedWalletsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var copyService = CopyTradingService.shared

    @State private var showingAddWallet = false
    @State private var newWalletAddress = ""
    @State private var newWalletNickname = ""
    @State private var isAdding = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                // Tracked Wallets Section
                if copyService.trackedWallets.isEmpty {
                    emptyState
                } else {
                    walletsSection
                }

                // Add Wallet Button
                Section {
                    Button(action: { showingAddWallet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(BrandColors.primary)
                            Text("Track New Wallet")
                                .foregroundColor(SemanticColors.textPrimary)
                        }
                    }
                }

                // Info Section
                Section {
                    infoRow(
                        icon: "bolt.fill",
                        title: "Auto-Copy",
                        description: "When enabled, trades are copied automatically using your settings"
                    )
                    infoRow(
                        icon: "shield.fill",
                        title: "Safe Mode",
                        description: "Only copies trades on major tokens (SOL, USDC, etc.)"
                    )
                } header: {
                    Text("How It Works")
                }
            }
            .navigationTitle("Copy Trading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await copyService.loadTrackedWallets()
                copyService.startWalletsListener()
            }
            .onDisappear {
                copyService.stopWalletsListener()
            }
            .sheet(isPresented: $showingAddWallet) {
                addWalletSheet
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Failed", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }

    // MARK: - Wallets Section

    private var walletsSection: some View {
        Section {
            ForEach(copyService.trackedWallets) { wallet in
                TrackedWalletRow(wallet: wallet)
            }
            .onDelete(perform: deleteWallets)
        } header: {
            Text("Tracked Wallets (\(copyService.trackedWallets.count)/3)")
        } footer: {
            Text("Swipe left to remove a wallet")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Section {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: IconSize.xxl))
                    .foregroundColor(SemanticColors.textSecondary)

                VStack(spacing: Spacing.sm) {
                    Text("No Wallets Tracked")
                        .font(Typography.headlineSmall)
                        .foregroundColor(SemanticColors.textPrimary)

                    Text("Add a wallet to start copy trading their swaps")
                        .font(Typography.bodySmall)
                        .foregroundColor(SemanticColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
        }
    }

    // MARK: - Info Row

    private func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(BrandColors.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.bodyMedium)
                    .foregroundColor(SemanticColors.textPrimary)
                Text(description)
                    .font(Typography.labelSmall)
                    .foregroundColor(SemanticColors.textSecondary)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Add Wallet Sheet

    private var addWalletSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Wallet Address", text: $newWalletAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))

                    TextField("Nickname (optional)", text: $newWalletNickname)
                } header: {
                    Text("Wallet Details")
                } footer: {
                    Text("Enter a Solana wallet address to track their trades")
                }
            }
            .navigationTitle("Track Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        resetAddWallet()
                        showingAddWallet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task { await addWallet() }
                    }
                    .disabled(newWalletAddress.isEmpty || isAdding)
                }
            }
            .overlay {
                if isAdding {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }

    // MARK: - Actions

    private func addWallet() async {
        isAdding = true

        do {
            try await copyService.addTrackedWallet(
                address: newWalletAddress.trimmingCharacters(in: .whitespaces),
                nickname: newWalletNickname.isEmpty ? nil : newWalletNickname
            )
            resetAddWallet()
            showingAddWallet = false
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        isAdding = false
    }

    private func deleteWallets(at offsets: IndexSet) {
        for index in offsets {
            let wallet = copyService.trackedWallets[index]
            Task {
                do {
                    try await copyService.removeTrackedWallet(wallet)
                } catch {
                    await MainActor.run {
                        deleteErrorMessage = "Failed to remove wallet: \(error.localizedDescription)"
                        showingDeleteError = true
                    }
                }
            }
        }
    }

    private func resetAddWallet() {
        newWalletAddress = ""
        newWalletNickname = ""
    }
}

// MARK: - Tracked Wallet Row

struct TrackedWalletRow: View {
    let wallet: TrackedWallet
    @StateObject private var copyService = CopyTradingService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                // Avatar
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String((wallet.nickname ?? wallet.walletAddress).prefix(1)).uppercased())
                            .font(Typography.headlineSmall)
                            .fontWeight(.bold)
                            .foregroundColor(SemanticColors.textInverse)
                    )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(wallet.nickname ?? shortenAddress(wallet.walletAddress))
                        .font(Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(SemanticColors.textPrimary)

                    Text(shortenAddress(wallet.walletAddress))
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                }

                Spacer()

                // Stats
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("\(wallet.stats.totalTrades) trades")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)

                    if wallet.stats.totalTrades > 0 {
                        Text("\(Int(wallet.stats.winRate * 100))% win")
                            .font(Typography.labelSmall)
                            .foregroundColor(SemanticColors.success)
                    }
                }
            }

            Divider()

            // Auto-Copy Toggle
            HStack {
                Toggle(isOn: Binding(
                    get: { wallet.autoCopyEnabled },
                    set: { newValue in
                        Task {
                            await copyService.toggleAutoCopy(for: wallet, enabled: newValue)
                        }
                    }
                )) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: wallet.autoCopyEnabled ? "bolt.fill" : "bolt")
                            .foregroundColor(wallet.autoCopyEnabled ? SemanticColors.success : SemanticColors.textSecondary)
                        Text("Auto-Copy")
                            .font(Typography.bodySmall)
                            .foregroundColor(SemanticColors.textPrimary)
                    }
                }
                .tint(SemanticColors.success)
            }

            // Execution Mode (only show if auto-copy enabled)
            if wallet.autoCopyEnabled {
                HStack {
                    Text("Mode")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)

                    Spacer()

                    Picker("", selection: Binding(
                        get: { wallet.executionMode },
                        set: { newMode in
                            Task {
                                await copyService.setExecutionMode(for: wallet, mode: newMode)
                            }
                        }
                    )) {
                        ForEach(TrackedWallet.ExecutionMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var avatarGradient: LinearGradient {
        let hash = wallet.walletAddress.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.7, brightness: 0.8),
                Color(hue: hue, saturation: 0.6, brightness: 0.6),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func shortenAddress(_ address: String) -> String {
        guard address.count > 8 else { return address }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}

#Preview {
    TrackedWalletsView()
        .environmentObject(ThemeManager.shared)
}
