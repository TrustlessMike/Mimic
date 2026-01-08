import SwiftUI
import PrivySDK

/// Clean, modern copy trading management view
struct TrackedWalletsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var copyService = PredictionCopyService.shared

    @State private var showAddWallet = false
    @State private var showDelegationSettings = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Auto-Execute Status Card
                    autoExecuteCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Pending Copies (if any)
                    if !copyService.pendingCopies.isEmpty {
                        pendingSection
                            .padding(.top, 24)
                    }

                    // Tracked Wallets
                    walletsSection
                        .padding(.top, 24)

                    // How It Works
                    infoSection
                        .padding(.top, 32)
                        .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Copy Trading")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .task {
                await loadData()
            }
            .onDisappear {
                copyService.stopPredictorsListener()
                copyService.stopPendingListener()
                copyService.stopDelegationListener()
            }
            .sheet(isPresented: $showAddWallet) {
                AddWalletSheet()
            }
            .sheet(isPresented: $showDelegationSettings) {
                DelegationSheet()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Auto-Execute Card

    private var autoExecuteCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(copyService.delegationActive
                              ? SemanticColors.success.opacity(0.15)
                              : BrandColors.primary.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: copyService.delegationActive ? "bolt.fill" : "bolt")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(copyService.delegationActive
                                         ? SemanticColors.success
                                         : BrandColors.primary)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(copyService.delegationActive ? "Auto-Execute On" : "Auto-Execute Off")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(SemanticColors.textPrimary)

                    Text(copyService.delegationActive
                         ? "Trades execute automatically"
                         : "Tap to enable automatic trading")
                        .font(.system(size: 14))
                        .foregroundColor(SemanticColors.textSecondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(16)

            // Stats row (when active)
            if copyService.delegationActive, let delegation = copyService.delegation {
                Divider()
                    .padding(.leading, 74)

                HStack(spacing: 0) {
                    StatItem(label: "Max/Trade", value: "$\(Int(delegation.maxCopyAmountUsd))")
                    StatItem(label: "Executed", value: "\(delegation.totalCopiesExecuted)")
                    StatItem(label: "Volume", value: "$\(Int(delegation.totalVolumeUsd))")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .onTapGesture {
            showDelegationSettings = true
        }
    }

    // MARK: - Pending Section

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ready to Copy")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SemanticColors.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(copyService.pendingCopies.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BrandColors.primary)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 1) {
                ForEach(copyService.pendingCopies) { pending in
                    PendingTradeRow(pending: pending)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Wallets Section

    private var walletsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tracked Wallets")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SemanticColors.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(copyService.trackedPredictors.count)/5")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SemanticColors.textSecondary)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 1) {
                // Wallet rows
                ForEach(copyService.trackedPredictors) { predictor in
                    TrackedWalletRow(predictor: predictor)
                }

                // Add button
                Button(action: { showAddWallet = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .frame(width: 44, height: 44)

                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(BrandColors.primary)
                        }

                        Text("Track a wallet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BrandColors.primary)

                        Spacer()
                    }
                    .padding(16)
                }
                .disabled(copyService.trackedPredictors.count >= 5)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)

            if copyService.trackedPredictors.isEmpty {
                Text("Track smart money wallets to copy their bets")
                    .font(.system(size: 14))
                    .foregroundColor(SemanticColors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SemanticColors.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                InfoRow(
                    icon: "bolt.fill",
                    title: "Instant Alerts",
                    description: "Get notified when tracked wallets bet"
                )

                Divider().padding(.leading, 56)

                InfoRow(
                    icon: "clock.fill",
                    title: "5 Minute Window",
                    description: "Copy within 5 min for similar prices"
                )

                Divider().padding(.leading, 56)

                InfoRow(
                    icon: "shield.checkered",
                    title: "Safe & Secure",
                    description: "Only Jupiter Prediction trades allowed"
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        await copyService.loadTrackedPredictors()
        await copyService.loadPendingCopies()
        await copyService.loadDelegationStatus()
        copyService.startPredictorsListener()
        copyService.startPendingListener()
        copyService.startDelegationListener()
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SemanticColors.textPrimary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(SemanticColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pending Trade Row

private struct PendingTradeRow: View {
    let pending: PendingCopyTrade
    @Environment(\.openURL) var openURL
    @StateObject private var copyService = PredictionCopyService.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Direction badge
                Text(pending.direction)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(pending.direction == "YES" ? SemanticColors.success : SemanticColors.error)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(pending.marketTitle ?? "Unknown Market")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SemanticColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text("by \(pending.trackedWalletNickname ?? shortenAddress(pending.trackedWallet))")
                            .font(.system(size: 13))
                            .foregroundColor(SemanticColors.textSecondary)

                        TimeRemainingBadge(expiresAt: pending.expiresAt)
                    }
                }

                Spacer()
            }

            HStack(spacing: 12) {
                // Original bet
                VStack(alignment: .leading, spacing: 2) {
                    Text("Original")
                        .font(.system(size: 12))
                        .foregroundColor(SemanticColors.textSecondary)
                    Text("$\(pending.originalAmount, specifier: "%.0f")")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SemanticColors.textPrimary)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.tertiaryLabel))

                // Your copy
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your copy")
                        .font(.system(size: 12))
                        .foregroundColor(SemanticColors.textSecondary)
                    Text("$\(pending.suggestedAmount, specifier: "%.0f")")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(BrandColors.primary)
                }

                Spacer()

                // Actions
                HStack(spacing: 8) {
                    Button("Skip") {
                        Task {
                            await copyService.skipPendingCopy(pending)
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SemanticColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)

                    Button {
                        if let url = copyService.buildJupiterUrl(for: pending) {
                            openURL(url)
                        }
                    } label: {
                        Text("Copy")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(BrandColors.primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private func shortenAddress(_ address: String) -> String {
        guard address.count > 8 else { return address }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}

// MARK: - Tracked Wallet Row

private struct TrackedWalletRow: View {
    let predictor: TrackedPredictor
    @StateObject private var copyService = PredictionCopyService.shared

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(avatarGradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String((predictor.nickname ?? predictor.walletAddress).prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(predictor.nickname ?? shortenAddress(predictor.walletAddress))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(SemanticColors.textPrimary)

                if let stats = predictor.stats, stats.totalBets > 0 {
                    HStack(spacing: 8) {
                        Text("\(stats.totalBets) bets")
                            .foregroundColor(SemanticColors.textSecondary)

                        Text("\(Int(stats.winRate * 100))% win")
                            .foregroundColor(SemanticColors.success)
                    }
                    .font(.system(size: 13))
                } else {
                    Text(shortenAddress(predictor.walletAddress))
                        .font(.system(size: 13))
                        .foregroundColor(SemanticColors.textSecondary)
                }
            }

            Spacer()

            // Auto-copy toggle
            Toggle("", isOn: Binding(
                get: { predictor.autoCopyEnabled },
                set: { newValue in
                    Task {
                        await copyService.toggleAutoCopy(for: predictor, enabled: newValue)
                    }
                }
            ))
            .labelsHidden()
            .tint(SemanticColors.success)
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private var avatarGradient: LinearGradient {
        let hash = predictor.walletAddress.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.65, brightness: 0.75),
                Color(hue: hue, saturation: 0.55, brightness: 0.55),
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

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(BrandColors.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SemanticColors.textPrimary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(SemanticColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Time Remaining Badge

private struct TimeRemainingBadge: View {
    let expiresAt: Date
    @State private var timeRemaining: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formatTime())
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(timeRemaining < 60 ? SemanticColors.error : SemanticColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(4)
            .onAppear { timeRemaining = expiresAt.timeIntervalSinceNow }
            .onReceive(timer) { _ in timeRemaining = expiresAt.timeIntervalSinceNow }
    }

    private func formatTime() -> String {
        if timeRemaining <= 0 { return "Expired" }
        let min = Int(timeRemaining) / 60
        let sec = Int(timeRemaining) % 60
        return min > 0 ? "\(min)m \(sec)s" : "\(sec)s"
    }
}

// MARK: - Add Wallet Sheet

private struct AddWalletSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var copyService = PredictionCopyService.shared

    @State private var address = ""
    @State private var nickname = ""
    @State private var autoCopy = true
    @State private var isAdding = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Wallet Address", text: $address)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))

                    TextField("Nickname (optional)", text: $nickname)

                    Toggle("Enable Auto-Copy", isOn: $autoCopy)
                } footer: {
                    Text("Paste a wallet address from the feed or leaderboard")
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(SemanticColors.error)
                    }
                }
            }
            .navigationTitle("Track Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task { await addWallet() }
                    }
                    .fontWeight(.semibold)
                    .disabled(address.isEmpty || isAdding)
                }
            }
            .disabled(isAdding)
            .overlay {
                if isAdding {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .overlay(ProgressView())
                }
            }
        }
    }

    private func addWallet() async {
        isAdding = true
        errorMessage = ""

        do {
            try await copyService.addTrackedPredictor(
                address: address.trimmingCharacters(in: .whitespaces),
                nickname: nickname.isEmpty ? nil : nickname,
                autoCopyEnabled: autoCopy
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isAdding = false
    }
}

// MARK: - Delegation Sheet

private struct DelegationSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var copyService = PredictionCopyService.shared
    @StateObject private var privyService = HybridPrivyService.shared

    @State private var maxAmount: Double = 50
    @State private var copyPercent: Double = 10
    @State private var minBet: Double = 5
    @State private var duration: Int = 30
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showRevokeConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                if copyService.delegationActive {
                    activeSection
                } else {
                    setupSection
                }

                securitySection
            }
            .navigationTitle(copyService.delegationActive ? "Auto-Execute" : "Enable Auto-Execute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .disabled(isLoading)
            .confirmationDialog("Disable Auto-Execute?", isPresented: $showRevokeConfirm, titleVisibility: .visible) {
                Button("Disable", role: .destructive) {
                    Task { await revoke() }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // Active delegation view
    private var activeSection: some View {
        Group {
            Section {
                if let delegation = copyService.delegation {
                    LabeledContent("Max per trade", value: "$\(Int(delegation.maxCopyAmountUsd))")
                    LabeledContent("Copy percentage", value: "\(Int(delegation.copyPercentage))%")
                    LabeledContent("Trades executed", value: "\(delegation.totalCopiesExecuted)")
                    LabeledContent("Total volume", value: "$\(Int(delegation.totalVolumeUsd))")

                    if delegation.expiresAt > Date() {
                        let days = Calendar.current.dateComponents([.day], from: Date(), to: delegation.expiresAt).day ?? 0
                        LabeledContent("Expires in", value: "\(days) days")
                    }
                }
            } header: {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .foregroundColor(SemanticColors.success)
            }

            Section {
                Button(role: .destructive) {
                    showRevokeConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Disable Auto-Execute")
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // Setup new delegation
    private var setupSection: some View {
        Group {
            Section("Trade Limits") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max per trade")
                        Spacer()
                        Text("$\(Int(maxAmount))")
                            .foregroundColor(BrandColors.primary)
                            .fontWeight(.semibold)
                    }
                    Slider(value: $maxAmount, in: 10...500, step: 10)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Copy percentage")
                        Spacer()
                        Text("\(Int(copyPercent))%")
                            .foregroundColor(BrandColors.primary)
                            .fontWeight(.semibold)
                    }
                    Slider(value: $copyPercent, in: 1...100, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Min bet to copy")
                        Spacer()
                        Text("$\(Int(minBet))")
                            .foregroundColor(BrandColors.primary)
                            .fontWeight(.semibold)
                    }
                    Slider(value: $minBet, in: 1...100, step: 1)
                }
            }

            Section("Duration") {
                Picker("", selection: $duration) {
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("1 year").tag(365)
                }
                .pickerStyle(.segmented)
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(SemanticColors.error)
                }
            }

            Section {
                Button {
                    Task { await enable() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Label("Enable Auto-Execute", systemImage: "bolt.fill")
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                }
                .listRowBackground(BrandColors.primary)
            }
        }
    }

    private var securitySection: some View {
        Section("Security") {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Secure Delegation")
                        .font(.system(size: 15, weight: .medium))
                    Text("Only Jupiter Prediction trades. Funds stay in your wallet.")
                        .font(.system(size: 13))
                        .foregroundColor(SemanticColors.textSecondary)
                }
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(SemanticColors.success)
            }
        }
    }

    private func enable() async {
        isLoading = true
        errorMessage = ""

        do {
            guard let token = try await privyService.getAccessToken() else {
                throw PredictionCopyError.notAuthenticated
            }

            try await copyService.approveDelegation(
                maxCopyAmountUsd: maxAmount,
                copyPercentage: copyPercent,
                minBetSizeUsd: minBet,
                expirationDays: duration,
                privyAccessToken: token
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func revoke() async {
        isLoading = true
        do {
            try await copyService.revokeDelegation()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    TrackedWalletsView()
        .environmentObject(ThemeManager.shared)
}
