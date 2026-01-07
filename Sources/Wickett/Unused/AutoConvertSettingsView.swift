import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Wickett", category: "AutoConvertSettings")

struct AutoConvertSettingsView: View {
    @ObservedObject private var delegationManager = DelegationManager.shared
    @EnvironmentObject var privyService: HybridPrivyService
    @Environment(\.colorScheme) var colorScheme

    @State private var showPortfolioEditor = false
    @State private var portfolio: [PortfolioAllocation] = []
    @State private var perSwapLimit: Double = 500
    @State private var dailyLimit: Double = 2000
    private let durationDays: Int = 90

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showConfetti = false
    @State private var isInitialLoading = true

    var body: some View {
        ZStack {
            // Clean White/Black Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    if isInitialLoading && delegationManager.delegationStatus == nil {
                        skeletonContent
                    } else {
                        // Header
                        VStack(spacing: 8) {
                            Text(hasActiveDelegation ? "Auto-Pilot Active" : "Configure Auto-Pilot")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.primary)
                            
                            Text(hasActiveDelegation ? "Your payments are being automatically converted." : "Choose how you want to receive your money.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 10)

                        // 1. Portfolio Card (Hero)
                        portfolioHeroCard

                        // 2. Safety Limits (Clean Rows)
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Safety Limits")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 4)
                            
                            limitRow(
                                title: "Max Per Swap",
                                value: perSwapLimit,
                                range: 10...1000,
                                step: 10,
                                binding: $perSwapLimit
                            )
                            
                            Divider()
                            
                            limitRow(
                                title: "Daily Limit",
                                value: dailyLimit,
                                range: 100...5000,
                                step: 100,
                                binding: $dailyLimit
                            )
                        }
                        .padding(24)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(24)

                        // 3. Main Action
                        mainActionButton
                            .padding(.top, 8)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPortfolioEditor) {
                PortfolioAllocationView(
                    portfolio: $portfolio,
                    onSave: { newPortfolio in
                        portfolio = newPortfolio
                        showPortfolioEditor = false
                    }
                )
            }
            .alert("Auto-Pilot", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .task {
                await loadDelegationStatus()
            }
            
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showConfetti = false
                        }
                    }
            }
        }
    }

    // MARK: - Components

    private var portfolioHeroCard: some View {
        Button(action: { showPortfolioEditor = true }) {
            VStack(spacing: 24) {
                if portfolio.isEmpty {
                    // Empty State
                    ZStack {
                        Circle()
                            .fill(BrandColors.primary.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 48))
                            .foregroundColor(BrandColors.primary)
                    }
                    .padding(.top, 10)
                    
                    VStack(spacing: 8) {
                        Text("Build Your Strategy")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Tap to select assets")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Populated State (Ring Chart)
                    ZStack {
                        PortfolioRingChart(portfolio: portfolio)
                            .frame(width: 140, height: 140)
                        
                        VStack(spacing: 2) {
                            Text("\(portfolio.count)")
                                .font(.title.weight(.bold))
                                .foregroundColor(.primary)
                            Text("Assets")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 10)
                    
                    VStack(spacing: 8) {
                        Text("Your Portfolio")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Mini tags for top 3 assets
                        HStack(spacing: 6) {
                            ForEach(portfolio.prefix(3)) { item in
                                Text(item.symbol)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(6)
                                    .foregroundColor(.secondary)
                            }
                            if portfolio.count > 3 {
                                Text("+\(portfolio.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(portfolio.isEmpty ? BrandColors.primary.opacity(0.3) : Color.clear, lineWidth: portfolio.isEmpty ? 1 : 0)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
        }
    }

    private func limitRow(title: String, value: Double, range: ClosedRange<Double>, step: Double, binding: Binding<Double>) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(Int(value))")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Slider(value: binding, in: range, step: step)
                .tint(BrandColors.primary)
        }
    }

    private var mainActionButton: some View {
        Button(action: {
            if hasActiveDelegation {
                Task { await handleRevokeDelegation() }
            } else {
                Task { await handleEnableDelegation() }
            }
        }) {
            HStack {
                if delegationManager.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(hasActiveDelegation ? "Disable Auto-Pilot" : "Enable Auto-Pilot")
                        .font(.headline.weight(.semibold))
                    
                    if !hasActiveDelegation {
                        Image(systemName: "bolt.fill")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                hasActiveDelegation ? Color.red.opacity(0.1) : BrandColors.primary
            )
            .foregroundColor(hasActiveDelegation ? .red : .white)
            .cornerRadius(14)
        }
        .disabled(delegationManager.isLoading || (!hasActiveDelegation && !canEnable))
        .opacity((!hasActiveDelegation && !canEnable) ? 0.6 : 1.0)
    }

    // MARK: - Skeleton Loading

    private var skeletonContent: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 200)
            
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 150)
            
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray5))
                .frame(height: 54)
        }
    }

    // MARK: - Logic Helpers

    private var hasActiveDelegation: Bool {
        delegationManager.delegationStatus?.hasActiveDelegation ?? false
    }

    private var canEnable: Bool {
        !portfolio.isEmpty && delegationManager.validatePortfolio(portfolio).isValid
    }

    private func loadDelegationStatus() async {
        await delegationManager.fetchDelegationStatus()
        isInitialLoading = false
    }

    private func handleEnableDelegation() async {
        guard !delegationManager.isLoading else { return }

        let (isValid, error) = delegationManager.validatePortfolio(portfolio)
        guard isValid else {
            alertMessage = error ?? "Invalid portfolio configuration"
            showAlert = true
            return
        }

        do {
            logger.info("📝 Creating delegation with Privy policy...")
            let response = try await delegationManager.approveDelegationV2(
                portfolio: portfolio,
                maxSwapAmountUsd: perSwapLimit,
                dailyLimitUsd: dailyLimit,
                expirationDays: durationDays
            )

            logger.info("✅ Auto-convert enabled successfully!")
            HapticManager.shared.success()
            withAnimation { showConfetti = true }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            alertMessage = response.message
            showAlert = true
            await loadDelegationStatus()
        } catch {
            logger.error("❌ Failed to enable: \(error)")
            alertMessage = "Failed to enable: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func handleRevokeDelegation() async {
        do {
            let message = try await delegationManager.revokeDelegationV2()
            alertMessage = message
            showAlert = true
            await loadDelegationStatus()
        } catch {
            alertMessage = "Failed to revoke: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

#Preview {
    NavigationView {
        AutoConvertSettingsView()
            .environmentObject(HybridPrivyService.shared)
    }
}
