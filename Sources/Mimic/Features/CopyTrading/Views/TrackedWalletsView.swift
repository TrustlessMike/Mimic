import SwiftUI
import PrivySDK

/// View for managing tracked predictors and prediction copy trading
struct TrackedWalletsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @StateObject private var copyService = PredictionCopyService.shared

    @State private var showingAddPredictor = false
    @State private var newWalletAddress = ""
    @State private var newWalletNickname = ""
    @State private var enableAutoCopyOnAdd = true
    @State private var isAdding = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // Delegation state
    @State private var showingDelegationSettings = false
    @State private var isExecutingCopy = false

    var body: some View {
        NavigationStack {
            List {
                // Auto-Execute Delegation Section
                delegationSection

                // Pending Copy Trades Section
                if !copyService.pendingCopies.isEmpty {
                    pendingCopiesSection
                }

                // Tracked Predictors Section
                if copyService.trackedPredictors.isEmpty {
                    emptyState
                } else {
                    predictorsSection
                }

                // Add Predictor Button
                Section {
                    Button(action: { showingAddPredictor = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(BrandColors.primary)
                            Text("Track Smart Money Wallet")
                                .foregroundColor(SemanticColors.textPrimary)
                        }
                    }
                }

                // Info Section
                Section {
                    infoRow(
                        icon: "bolt.fill",
                        title: "Auto-Copy",
                        description: "Get notified instantly when tracked wallets place bets"
                    )
                    infoRow(
                        icon: "clock.fill",
                        title: "5 Minute Window",
                        description: "Copy trades within 5 minutes to get similar prices"
                    )
                    infoRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Smart Money",
                        description: "Track proven winners from the leaderboard"
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
                await copyService.loadTrackedPredictors()
                await copyService.loadPendingCopies()
                await copyService.loadDelegationStatus()
                copyService.startPredictorsListener()
                copyService.startPendingListener()
                copyService.startDelegationListener()
            }
            .onDisappear {
                copyService.stopPredictorsListener()
                copyService.stopPendingListener()
                copyService.stopDelegationListener()
            }
            .sheet(isPresented: $showingAddPredictor) {
                addPredictorSheet
            }
            .sheet(isPresented: $showingDelegationSettings) {
                DelegationSettingsSheet()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Delegation Section

    private var delegationSection: some View {
        Section {
            if copyService.delegationActive, let delegation = copyService.delegation {
                // Active delegation status
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(SemanticColors.success)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Auto-Execute Enabled")
                                .font(Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(SemanticColors.textPrimary)

                            Text("Trades will execute automatically")
                                .font(Typography.labelSmall)
                                .foregroundColor(SemanticColors.textSecondary)
                        }

                        Spacer()

                        Button(action: { showingDelegationSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(SemanticColors.textSecondary)
                        }
                    }

                    // Stats row
                    HStack(spacing: Spacing.lg) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Max per trade")
                                .font(Typography.labelSmall)
                                .foregroundColor(SemanticColors.textSecondary)
                            Text("$\(Int(delegation.maxCopyAmountUsd))")
                                .font(Typography.bodySmall)
                                .fontWeight(.medium)
                                .foregroundColor(SemanticColors.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Executed")
                                .font(Typography.labelSmall)
                                .foregroundColor(SemanticColors.textSecondary)
                            Text("\(delegation.totalCopiesExecuted) trades")
                                .font(Typography.bodySmall)
                                .fontWeight(.medium)
                                .foregroundColor(SemanticColors.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Volume")
                                .font(Typography.labelSmall)
                                .foregroundColor(SemanticColors.textSecondary)
                            Text("$\(Int(delegation.totalVolumeUsd))")
                                .font(Typography.bodySmall)
                                .fontWeight(.medium)
                                .foregroundColor(SemanticColors.textPrimary)
                        }
                    }

                    // Expiry info
                    if delegation.expiresAt > Date() {
                        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: delegation.expiresAt).day ?? 0
                        Text("Expires in \(daysRemaining) days")
                            .font(Typography.labelSmall)
                            .foregroundColor(SemanticColors.textSecondary)
                    }
                }
                .padding(.vertical, Spacing.xs)
            } else {
                // Enable delegation prompt
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Image(systemName: "bolt.shield")
                            .foregroundColor(BrandColors.primary)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Auto-Execute Copy Trades")
                                .font(Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(SemanticColors.textPrimary)

                            Text("Automatically copy trades without tapping")
                                .font(Typography.labelSmall)
                                .foregroundColor(SemanticColors.textSecondary)
                        }
                    }

                    Button(action: { showingDelegationSettings = true }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Enable Auto-Execute")
                        }
                        .font(Typography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(SemanticColors.textInverse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .fill(BrandColors.primaryGradient)
                        )
                    }
                    .disabled(copyService.isDelegationLoading)
                }
                .padding(.vertical, Spacing.xs)
            }
        } header: {
            Text("Auto-Execute")
        } footer: {
            if copyService.delegationActive {
                Text("Your trades are automatically executed when tracked wallets bet")
            } else {
                Text("Enable to have trades automatically execute without manual approval")
            }
        }
    }

    // MARK: - Pending Copies Section

    private var pendingCopiesSection: some View {
        Section {
            ForEach(copyService.pendingCopies) { pending in
                PendingCopyRow(pending: pending) { action in
                    handlePendingAction(pending, action: action)
                }
            }
        } header: {
            HStack {
                Text("Ready to Copy")
                Spacer()
                Text("\(copyService.pendingCopies.count)")
                    .font(Typography.labelSmall)
                    .foregroundColor(SemanticColors.textSecondary)
            }
        } footer: {
            Text("Tap to copy these bets on Jupiter")
        }
    }

    // MARK: - Predictors Section

    private var predictorsSection: some View {
        Section {
            ForEach(copyService.trackedPredictors) { predictor in
                TrackedPredictorRow(predictor: predictor)
            }
            .onDelete(perform: deletePredictors)
        } header: {
            Text("Tracked Predictors (\(copyService.trackedPredictors.count)/5)")
        } footer: {
            Text("Swipe left to remove")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Section {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "person.2.badge.gearshape")
                    .font(.system(size: IconSize.xxl))
                    .foregroundColor(SemanticColors.textSecondary)

                VStack(spacing: Spacing.sm) {
                    Text("No Predictors Tracked")
                        .font(Typography.headlineSmall)
                        .foregroundColor(SemanticColors.textPrimary)

                    Text("Track smart money wallets from the leaderboard to copy their bets")
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

    // MARK: - Add Predictor Sheet

    private var addPredictorSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Wallet Address", text: $newWalletAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))

                    TextField("Nickname (optional)", text: $newWalletNickname)

                    Toggle("Enable Auto-Copy", isOn: $enableAutoCopyOnAdd)
                } header: {
                    Text("Wallet Details")
                } footer: {
                    Text("Copy a wallet address from the Feed or Leaderboard")
                }
            }
            .navigationTitle("Track Predictor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        resetAddPredictor()
                        showingAddPredictor = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task { await addPredictor() }
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

    private func addPredictor() async {
        isAdding = true

        do {
            try await copyService.addTrackedPredictor(
                address: newWalletAddress.trimmingCharacters(in: .whitespaces),
                nickname: newWalletNickname.isEmpty ? nil : newWalletNickname,
                autoCopyEnabled: enableAutoCopyOnAdd
            )
            resetAddPredictor()
            showingAddPredictor = false
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        isAdding = false
    }

    private func deletePredictors(at offsets: IndexSet) {
        for index in offsets {
            let predictor = copyService.trackedPredictors[index]
            Task {
                try? await copyService.removeTrackedPredictor(predictor)
            }
        }
    }

    private func handlePendingAction(_ pending: PendingCopyTrade, action: PendingCopyAction) {
        switch action {
        case .copy:
            if let url = copyService.buildJupiterUrl(for: pending) {
                openURL(url)
            }
        case .skip:
            Task {
                await copyService.skipPendingCopy(pending)
            }
        }
    }

    private func resetAddPredictor() {
        newWalletAddress = ""
        newWalletNickname = ""
        enableAutoCopyOnAdd = true
    }
}

// MARK: - Pending Copy Action

enum PendingCopyAction {
    case copy
    case skip
}

// MARK: - Pending Copy Row

struct PendingCopyRow: View {
    let pending: PendingCopyTrade
    let onAction: (PendingCopyAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                // Direction badge
                Text(pending.direction)
                    .font(Typography.labelSmall)
                    .fontWeight(.bold)
                    .foregroundColor(SemanticColors.textInverse)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.xs)
                            .fill(pending.direction == "YES" ? SemanticColors.success : SemanticColors.error)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(pending.marketTitle ?? "Unknown Market")
                        .font(Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(SemanticColors.textPrimary)
                        .lineLimit(2)

                    Text("by \(pending.trackedWalletNickname ?? shortenAddress(pending.trackedWallet))")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                }

                Spacer()

                // Time remaining
                TimeRemainingBadge(expiresAt: pending.expiresAt)
            }

            // Amount info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Original Bet")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                    Text("$\(pending.originalAmount, specifier: "%.2f")")
                        .font(Typography.bodySmall)
                        .foregroundColor(SemanticColors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Your Copy")
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                    Text("$\(pending.suggestedAmount, specifier: "%.2f")")
                        .font(Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(BrandColors.primary)
                }
            }

            // Action buttons
            HStack(spacing: Spacing.md) {
                Button(action: { onAction(.skip) }) {
                    Text("Skip")
                        .font(Typography.bodySmall)
                        .foregroundColor(SemanticColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .stroke(SemanticColors.divider, lineWidth: 1)
                        )
                }

                Button(action: { onAction(.copy) }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Copy on Jupiter")
                    }
                    .font(Typography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(SemanticColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(BrandColors.primaryGradient)
                    )
                }
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private func shortenAddress(_ address: String) -> String {
        guard address.count > 8 else { return address }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}

// MARK: - Time Remaining Badge

struct TimeRemainingBadge: View {
    let expiresAt: Date
    @State private var timeRemaining: TimeInterval = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formatTimeRemaining())
            .font(Typography.labelSmall)
            .fontWeight(.medium)
            .foregroundColor(timeRemaining < 60 ? SemanticColors.error : SemanticColors.textSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xs)
                    .fill(SemanticColors.backgroundSecondary)
            )
            .onAppear {
                timeRemaining = expiresAt.timeIntervalSinceNow
            }
            .onReceive(timer) { _ in
                timeRemaining = expiresAt.timeIntervalSinceNow
            }
    }

    private func formatTimeRemaining() -> String {
        if timeRemaining <= 0 {
            return "Expired"
        }
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// MARK: - Tracked Predictor Row

struct TrackedPredictorRow: View {
    let predictor: TrackedPredictor
    @StateObject private var copyService = PredictionCopyService.shared
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                // Avatar
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String((predictor.nickname ?? predictor.walletAddress).prefix(1)).uppercased())
                            .font(Typography.headlineSmall)
                            .fontWeight(.bold)
                            .foregroundColor(SemanticColors.textInverse)
                    )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(predictor.nickname ?? shortenAddress(predictor.walletAddress))
                        .font(Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(SemanticColors.textPrimary)

                    Text(shortenAddress(predictor.walletAddress))
                        .font(Typography.labelSmall)
                        .foregroundColor(SemanticColors.textSecondary)
                }

                Spacer()

                // Stats
                if let stats = predictor.stats, stats.totalBets > 0 {
                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text("\(stats.totalBets) bets")
                            .font(Typography.labelSmall)
                            .foregroundColor(SemanticColors.textSecondary)

                        Text("\(Int(stats.winRate * 100))% win")
                            .font(Typography.labelSmall)
                            .foregroundColor(SemanticColors.success)
                    }
                }
            }

            Divider()

            // Auto-Copy Toggle
            HStack {
                Toggle(isOn: Binding(
                    get: { predictor.autoCopyEnabled },
                    set: { newValue in
                        Task {
                            await copyService.toggleAutoCopy(for: predictor, enabled: newValue)
                        }
                    }
                )) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: predictor.autoCopyEnabled ? "bolt.fill" : "bolt")
                            .foregroundColor(predictor.autoCopyEnabled ? SemanticColors.success : SemanticColors.textSecondary)
                        Text("Auto-Copy")
                            .font(Typography.bodySmall)
                            .foregroundColor(SemanticColors.textPrimary)
                    }
                }
                .tint(SemanticColors.success)
            }

            // Copy Settings (only show if auto-copy enabled)
            if predictor.autoCopyEnabled {
                Button(action: { showingSettings = true }) {
                    HStack {
                        Text("Copy up to $\(Int(predictor.maxCopyAmountUsd)) per bet")
                            .font(Typography.labelSmall)
                            .foregroundColor(SemanticColors.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(SemanticColors.textSecondary)
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    CopySettingsSheet(predictor: predictor)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var avatarGradient: LinearGradient {
        let hash = predictor.walletAddress.hashValue
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

// MARK: - Copy Settings Sheet

struct CopySettingsSheet: View {
    let predictor: TrackedPredictor
    @Environment(\.dismiss) var dismiss
    @StateObject private var copyService = PredictionCopyService.shared

    @State private var copyPercentage: Double
    @State private var maxCopyAmount: Double
    @State private var minBetSize: Double

    init(predictor: TrackedPredictor) {
        self.predictor = predictor
        _copyPercentage = State(initialValue: predictor.copyPercentage)
        _maxCopyAmount = State(initialValue: predictor.maxCopyAmountUsd)
        _minBetSize = State(initialValue: predictor.minBetSizeUsd)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Copy Percentage")
                            Spacer()
                            Text("\(Int(copyPercentage))%")
                                .foregroundColor(BrandColors.primary)
                        }
                        Slider(value: $copyPercentage, in: 1...100, step: 1)
                    }
                } footer: {
                    Text("Percentage of the original bet amount to copy")
                }

                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Max Copy Amount")
                            Spacer()
                            Text("$\(Int(maxCopyAmount))")
                                .foregroundColor(BrandColors.primary)
                        }
                        Slider(value: $maxCopyAmount, in: 5...500, step: 5)
                    }
                } footer: {
                    Text("Maximum amount per copy bet")
                }

                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Min Bet to Copy")
                            Spacer()
                            Text("$\(Int(minBetSize))")
                                .foregroundColor(BrandColors.primary)
                        }
                        Slider(value: $minBetSize, in: 1...100, step: 1)
                    }
                } footer: {
                    Text("Only copy bets larger than this amount")
                }
            }
            .navigationTitle("Copy Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await copyService.updateCopySettings(
                                for: predictor,
                                copyPercentage: copyPercentage,
                                maxCopyAmountUsd: maxCopyAmount,
                                minBetSizeUsd: minBetSize
                            )
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Delegation Settings Sheet

struct DelegationSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var copyService = PredictionCopyService.shared
    @StateObject private var privyService = HybridPrivyService.shared

    @State private var maxCopyAmount: Double = 50
    @State private var copyPercentage: Double = 10
    @State private var minBetSize: Double = 5
    @State private var expirationDays: Int = 30
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingRevokeConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                if copyService.delegationActive {
                    // Active delegation - show status and revoke option
                    Section {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(SemanticColors.success)
                            Text("Auto-Execute is Active")
                                .font(Typography.bodyMedium)
                                .foregroundColor(SemanticColors.textPrimary)
                        }

                        if let delegation = copyService.delegation {
                            LabeledContent("Max per trade", value: "$\(Int(delegation.maxCopyAmountUsd))")
                            LabeledContent("Copy percentage", value: "\(Int(delegation.copyPercentage))%")
                            LabeledContent("Min bet size", value: "$\(Int(delegation.minBetSizeUsd))")
                            LabeledContent("Trades executed", value: "\(delegation.totalCopiesExecuted)")
                            LabeledContent("Total volume", value: "$\(Int(delegation.totalVolumeUsd))")

                            if delegation.expiresAt > Date() {
                                let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: delegation.expiresAt).day ?? 0
                                LabeledContent("Expires in", value: "\(daysRemaining) days")
                            }
                        }
                    } header: {
                        Text("Current Settings")
                    }

                    Section {
                        Button(role: .destructive, action: { showingRevokeConfirm = true }) {
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
                        .disabled(isLoading)
                    } footer: {
                        Text("Disabling will require you to manually approve each copy trade")
                    }
                } else {
                    // Setup new delegation
                    Section {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Max Copy Amount")
                                Spacer()
                                Text("$\(Int(maxCopyAmount))")
                                    .foregroundColor(BrandColors.primary)
                                    .fontWeight(.semibold)
                            }
                            Slider(value: $maxCopyAmount, in: 10...500, step: 10)
                        }
                    } header: {
                        Text("Trade Limits")
                    } footer: {
                        Text("Maximum amount that will be used per copy trade")
                    }

                    Section {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Copy Percentage")
                                Spacer()
                                Text("\(Int(copyPercentage))%")
                                    .foregroundColor(BrandColors.primary)
                                    .fontWeight(.semibold)
                            }
                            Slider(value: $copyPercentage, in: 1...100, step: 1)
                        }
                    } footer: {
                        Text("Percentage of the original bet to copy")
                    }

                    Section {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Min Bet to Copy")
                                Spacer()
                                Text("$\(Int(minBetSize))")
                                    .foregroundColor(BrandColors.primary)
                                    .fontWeight(.semibold)
                            }
                            Slider(value: $minBetSize, in: 1...100, step: 1)
                        }
                    } footer: {
                        Text("Only copy bets larger than this amount")
                    }

                    Section {
                        Picker("Duration", selection: $expirationDays) {
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("1 year").tag(365)
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Expiration")
                    } footer: {
                        Text("Auto-execute will need to be re-enabled after this period")
                    }

                    Section {
                        Button(action: enableDelegation) {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .tint(SemanticColors.textInverse)
                                } else {
                                    Image(systemName: "bolt.fill")
                                    Text("Enable Auto-Execute")
                                }
                                Spacer()
                            }
                            .font(Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(SemanticColors.textInverse)
                            .padding(.vertical, Spacing.sm)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .fill(BrandColors.primaryGradient)
                        )
                        .disabled(isLoading)
                    } footer: {
                        Text("You'll be asked to approve this in your wallet")
                    }
                }

                // Security info
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Secure Delegation")
                                .font(Typography.bodySmall)
                                .foregroundColor(SemanticColors.textPrimary)
                            Text("Only Jupiter Prediction Market trades are allowed. Your funds remain in your wallet at all times.")
                                .font(Typography.labelSmall)
                                .foregroundColor(SemanticColors.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(SemanticColors.success)
                    }
                } header: {
                    Text("Security")
                }
            }
            .navigationTitle(copyService.delegationActive ? "Auto-Execute Settings" : "Enable Auto-Execute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog(
                "Disable Auto-Execute?",
                isPresented: $showingRevokeConfirm,
                titleVisibility: .visible
            ) {
                Button("Disable", role: .destructive) {
                    Task { await revokeDelegation() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need to manually approve each copy trade after disabling.")
            }
        }
    }

    private func enableDelegation() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                // Get Privy access token
                guard let accessToken = try await privyService.getAccessToken() else {
                    throw PredictionCopyError.notAuthenticated
                }

                try await copyService.approveDelegation(
                    maxCopyAmountUsd: maxCopyAmount,
                    copyPercentage: copyPercentage,
                    minBetSizeUsd: minBetSize,
                    expirationDays: expirationDays,
                    privyAccessToken: accessToken
                )

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func revokeDelegation() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await copyService.revokeDelegation()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    TrackedWalletsView()
        .environmentObject(ThemeManager.shared)
}
