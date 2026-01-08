import SwiftUI

struct CoinbaseOnrampView: View {
    @StateObject private var viewModel = CoinbaseOnrampViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isProcessing = false

    private let swipeThreshold: CGFloat = 200

    var body: some View {
        ZStack {
            // Main Content
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, 16)

                Spacer()

                // Amount Display
                amountDisplay

                // Payment Method Pill
                paymentMethodPill
                    .padding(.top, 20)

                // Quick Amount Buttons
                quickAmountButtons
                    .padding(.top, 24)

                Spacer()

                // Custom Numpad
                numpad
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Swipe to Deposit Button
                swipeToDeposit
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .disabled(viewModel.state == .creatingSession || viewModel.state == .pollingStatus) // Disable interactions while processing
            
            // Processing Overlay
            if viewModel.state == .creatingSession || viewModel.state == .pollingStatus {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(BrandColors.primary)
                    
                    Text(viewModel.state == .creatingSession ? "Securing connection..." : "Processing deposit...")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if viewModel.state == .pollingStatus {
                        Button("Stop Checking") {
                            viewModel.cancel()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(32)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $viewModel.showCheckout) {
            if let session = viewModel.currentSession,
               let url = URL(string: session.checkoutUrl) {
                NavigationView {
                    CoinbaseSafariView(url: url) {
                        viewModel.handleCheckoutDismissed()
                    }
                    .navigationTitle("Coinbase Pay")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                viewModel.handleCheckoutDismissed()
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showApplePaySheet) {
            if let order = viewModel.currentApplePayOrder,
               let url = URL(string: order.paymentLinkUrl) {
                NavigationView {
                    CoinbaseSafariView(url: url) {
                        viewModel.handleApplePayDismissed()
                    }
                    .navigationTitle("Apple Pay")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                viewModel.handleApplePayDismissed()
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            if newState == .completed {
                // Auto-dismiss after success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()

            Text("Deposit")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .padding(.trailing, 16)
        }
    }

    // MARK: - Amount Display

    private var amountDisplay: some View {
        VStack(spacing: 8) {
            Text(viewModel.fiatAmount.isEmpty ? "$0" : "$\(viewModel.fiatAmount)")
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(viewModel.fiatAmount.isEmpty ? .secondary.opacity(0.5) : .primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal)
        }
    }

    // MARK: - Payment Method Pill

    private var paymentMethodPill: some View {
        Menu {
            Button(action: { viewModel.selectedPaymentMethod = .applePay }) {
                Label("Apple Pay", systemImage: "apple.logo")
            }
            Button(action: { viewModel.selectedPaymentMethod = .creditCard }) {
                Label("Debit Card", systemImage: "creditcard")
            }
            Button(action: { viewModel.selectedPaymentMethod = .creditCard }) {
                Label("Bank Account", systemImage: "building.columns")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.selectedPaymentMethod == .applePay ? "apple.logo" : "creditcard.fill")
                    .font(.subheadline)
                Text(viewModel.selectedPaymentMethod == .applePay ? "Apple Pay" : "Debit / Bank")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundColor(.primary)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(20)
        }
    }

    // MARK: - Quick Amount Buttons

    private var quickAmountButtons: some View {
        HStack(spacing: 12) {
            ForEach([30, 50, 100, 500], id: \.self) { amount in
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    viewModel.fiatAmount = "\(amount)"
                }) {
                    Text("$\(amount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 70, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Numpad

    private var numpad: some View {
        VStack(spacing: 12) {
            ForEach(numpadRows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        numpadButton(key)
                    }
                }
            }
        }
    }

    private let numpadRows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    private func numpadButton(_ key: String) -> some View {
        Button(action: { handleNumpadTap(key) }) {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 24))
                } else {
                    Text(key)
                        .font(.system(size: 32, weight: .medium))
                }
            }
            .foregroundColor(.primary)
            .frame(width: 80, height: 60)
            .contentShape(Rectangle())
        }
    }

    private func handleNumpadTap(_ key: String) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        switch key {
        case "⌫":
            if !viewModel.fiatAmount.isEmpty {
                viewModel.fiatAmount.removeLast()
            }
        case ".":
            if !viewModel.fiatAmount.contains(".") {
                viewModel.fiatAmount += viewModel.fiatAmount.isEmpty ? "0." : "."
            }
        default:
            if viewModel.fiatAmount.count < 6 {
                if let dotIndex = viewModel.fiatAmount.firstIndex(of: ".") {
                    let decimals = viewModel.fiatAmount.distance(from: dotIndex, to: viewModel.fiatAmount.endIndex) - 1
                    if decimals >= 2 { return }
                }
                viewModel.fiatAmount += key
            }
        }
    }

    // MARK: - Swipe to Deposit

    private var swipeToDeposit: some View {
        GeometryReader { geometry in
            let maxDrag = geometry.size.width - 70

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 35)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 70)

                // Progress fill
                if dragOffset > 0 {
                    RoundedRectangle(cornerRadius: 35)
                        .fill(BrandColors.primary.opacity(0.3))
                        .frame(width: dragOffset + 70, height: 70)
                }

                // Text
                HStack {
                    Spacer()
                    if viewModel.state == .completed {
                        Text("Success!")
                            .font(.headline)
                            .foregroundColor(.green)
                    } else {
                        Text("Swipe to Deposit")
                            .font(.headline)
                            .foregroundColor(canDeposit ? .primary.opacity(0.5) : .secondary.opacity(0.3))
                    }
                    Spacer()
                }

                // Draggable button
                Circle()
                    .fill(canDeposit ? BrandColors.primary : Color(.systemGray4))
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: dragOffset + 4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard canDeposit else { return }
                                let newOffset = max(0, min(value.translation.width, maxDrag))
                                dragOffset = newOffset
                            }
                            .onEnded { value in
                                guard canDeposit else { return }
                                if dragOffset > swipeThreshold {
                                    // Trigger deposit
                                    withAnimation(.spring()) {
                                        dragOffset = maxDrag
                                    }
                                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                                    impact.impactOccurred()
                                    
                                    Task {
                                        await viewModel.startOnramp()
                                        // Reset slider if it failed/cancelled
                                        if viewModel.state != .completed {
                                            withAnimation { dragOffset = 0 }
                                        }
                                    }
                                } else {
                                    // Reset
                                    withAnimation(.spring()) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: 70)
    }

    private var canDeposit: Bool {
        viewModel.state == .idle &&
        viewModel.canStartOnramp &&
        viewModel.parsedFiatAmount != nil &&
        (viewModel.parsedFiatAmount ?? 0) >= 5 // Minimum $5
    }
}

#Preview {
    CoinbaseOnrampView()
}
