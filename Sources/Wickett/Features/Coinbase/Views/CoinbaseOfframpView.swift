import SwiftUI

struct CoinbaseOfframpView: View {
    @StateObject private var viewModel = CoinbaseOfframpViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    private let swipeThreshold: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.top, 16)

            Spacer()

            // Amount Display
            amountDisplay

            // Balance Pill
            balancePill
                .padding(.top, 20)

            // Quick Amount Buttons
            quickAmountButtons
                .padding(.top, 24)

            Spacer()

            // Custom Numpad
            numpad
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            // Swipe to Cash Out Button
            swipeToCashOut
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
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
        .alert("Send USDC", isPresented: $viewModel.showTransferPrompt) {
            Button("I'll Send Manually", role: .none) {
                viewModel.confirmTransferIntent()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancel()
            }
        } message: {
            if let session = viewModel.currentSession {
                Text("To complete your withdrawal, send \(viewModel.formattedAmount) USDC to:\n\n\(session.depositAddress)\n\nOnce sent, your bank will receive the funds in 1-3 business days.")
            }
        }
        .onChange(of: viewModel.state) { newState in
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

            Text("Cash Out")
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
            HStack(spacing: 0) {
                Text("$")
                    .font(.system(size: 72, weight: .light))
                    .foregroundColor(viewModel.fiatAmount.isEmpty ? Color(.systemGray3) : .primary)

                Text(viewModel.fiatAmount.isEmpty ? "0" : viewModel.fiatAmount)
                    .font(.system(size: 72, weight: .light))
                    .foregroundColor(viewModel.fiatAmount.isEmpty ? Color(.systemGray3) : .primary)
            }

            // Error or insufficient balance message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            } else if !viewModel.hasSufficientBalance && viewModel.parsedFiatAmount != nil {
                Text("Insufficient USDC balance")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Balance Pill

    private var balancePill: some View {
        HStack(spacing: 8) {
            Image("TokenUSDC")
                .resizable()
                .frame(width: 20, height: 20)

            Text(viewModel.formattedUsdcBalance)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("available")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }

    // MARK: - Quick Amount Buttons

    private var quickAmountButtons: some View {
        HStack(spacing: 12) {
            ForEach([25, 50, 100], id: \.self) { amount in
                Button(action: {
                    viewModel.fiatAmount = "\(amount)"
                }) {
                    Text("$\(amount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                }
                .disabled(viewModel.state != .idle)
            }

            // Max button
            Button(action: {
                if let balance = viewModel.usdcBalance {
                    let maxAmount = NSDecimalNumber(decimal: balance).doubleValue
                    viewModel.fiatAmount = String(format: "%.0f", floor(maxAmount))
                }
            }) {
                Text("Max")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
            }
            .disabled(viewModel.state != .idle || viewModel.usdcBalance == nil)
        }
    }

    // MARK: - Numpad

    private var numpad: some View {
        VStack(spacing: 8) {
            ForEach(numpadRows, id: \.self) { row in
                HStack(spacing: 8) {
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
                        .font(.system(size: 22, weight: .medium))
                } else {
                    Text(key)
                        .font(.system(size: 28, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(.systemGray6))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
        .disabled(viewModel.state != .idle)
    }

    private func handleNumpadTap(_ key: String) {
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
            // Limit to reasonable amount
            if viewModel.fiatAmount.count < 7 {
                // Only allow 2 decimal places
                if let dotIndex = viewModel.fiatAmount.firstIndex(of: ".") {
                    let decimals = viewModel.fiatAmount.distance(from: dotIndex, to: viewModel.fiatAmount.endIndex) - 1
                    if decimals >= 2 { return }
                }
                viewModel.fiatAmount += key
            }
        }
    }

    // MARK: - Swipe to Cash Out

    private var swipeToCashOut: some View {
        GeometryReader { geometry in
            let maxDrag = geometry.size.width - 70

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color(.systemGray5))
                    .frame(height: 60)

                // Progress fill
                if dragOffset > 0 {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.green.opacity(0.3))
                        .frame(width: dragOffset + 60, height: 60)
                }

                // Text
                HStack {
                    Spacer()
                    if viewModel.state == .creatingSession || viewModel.state == .pollingStatus {
                        ProgressView()
                            .tint(.gray)
                    } else if viewModel.state == .completed {
                        Text("Cashed Out!")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    } else {
                        Text("Swipe to Cash Out")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(canCashOut ? Color(.systemGray) : Color(.systemGray3))
                    }
                    Spacer()
                }

                // Draggable button
                Circle()
                    .fill(canCashOut ? Color.green : Color(.systemGray4))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "chevron.right.2")
                            .font(.body.bold())
                            .foregroundColor(.white)
                    )
                    .offset(x: dragOffset + 4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard canCashOut else { return }
                                let newOffset = max(0, min(value.translation.width, maxDrag))
                                dragOffset = newOffset
                            }
                            .onEnded { value in
                                guard canCashOut else { return }
                                if dragOffset > swipeThreshold {
                                    // Trigger cash out
                                    withAnimation(.spring()) {
                                        dragOffset = maxDrag
                                    }
                                    Task {
                                        await viewModel.startOfframp()
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
        .frame(height: 60)
    }

    private var canCashOut: Bool {
        viewModel.state == .idle &&
        viewModel.canStartOfframp &&
        viewModel.parsedFiatAmount != nil &&
        (viewModel.parsedFiatAmount ?? 0) >= 1 && // Minimum $1
        viewModel.hasSufficientBalance
    }
}

#Preview {
    CoinbaseOfframpView()
}
