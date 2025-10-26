import SwiftUI

struct WalletView: View {
    let user: User

    @State private var paymentMethods: [PaymentMethod] = []
    @State private var cards: [PaymentCard] = []
    @State private var showAddPaymentMethod = false
    @State private var showAddCard = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Payment Methods Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Payment Methods")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                showAddPaymentMethod = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)

                        if paymentMethods.isEmpty {
                            EmptyStateCard(
                                icon: "creditcard.fill",
                                title: "No Payment Methods",
                                message: "Add a payment method to get started",
                                action: {
                                    showAddPaymentMethod = true
                                }
                            )
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(paymentMethods) { method in
                                    PaymentMethodRow(method: method)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Cards Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Cards")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                showAddCard = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)

                        if cards.isEmpty {
                            EmptyStateCard(
                                icon: "creditcard.and.123",
                                title: "No Cards",
                                message: "Add a debit or credit card",
                                action: {
                                    showAddCard = true
                                }
                            )
                            .padding(.horizontal)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(cards) { card in
                                        CardView(card: card)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadPaymentMethods()
                loadCards()
            }
            .sheet(isPresented: $showAddPaymentMethod) {
                AddPaymentMethodSheet(onDismiss: {
                    showAddPaymentMethod = false
                    loadPaymentMethods()
                })
            }
            .sheet(isPresented: $showAddCard) {
                AddCardSheet(onDismiss: {
                    showAddCard = false
                    loadCards()
                })
            }
        }
    }

    // MARK: - Helpers

    private func loadPaymentMethods() {
        // TODO: Fetch from backend
        // For now, show empty state
        paymentMethods = []
    }

    private func loadCards() {
        // TODO: Fetch from backend
        // For now, show empty state
        cards = []
    }
}

// MARK: - Payment Method Row

struct PaymentMethodRow: View {
    let method: PaymentMethod

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(method.type.color.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: method.type.icon)
                    .font(.title3)
                    .foregroundColor(method.type.color)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(method.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(method.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status Badge
            if method.isDefault {
                Text("Default")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Card View

struct CardView: View {
    let card: PaymentCard

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Header
            HStack {
                Image(systemName: card.brand.icon)
                    .font(.title2)
                    .foregroundColor(.white)

                Spacer()

                if card.isDefault {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Card Number
            Text("•••• •••• •••• \(card.lastFour)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)

            // Card Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Card Holder")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(card.holderName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Expires")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(card.expiryDate)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(20)
        .frame(width: 300, height: 180)
        .background(
            LinearGradient(
                colors: card.brand.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Empty State Card

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button(action: action) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Now")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Add Payment Method Sheet

struct AddPaymentMethodSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    VStack(spacing: 12) {
                        Text("Add Payment Method")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("This feature is coming soon.\nYou'll be able to add bank accounts, digital wallets, and more.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }

                Spacer()
            }
            .navigationTitle("Add Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add Card Sheet

struct AddCardSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: "creditcard.and.123")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    VStack(spacing: 12) {
                        Text("Add Card")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("This feature is coming soon.\nYou'll be able to add debit and credit cards securely.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }

                Spacer()
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Payment Method Model

struct PaymentMethod: Identifiable {
    let id = UUID()
    let type: PaymentMethodType
    let name: String
    let subtitle: String
    let isDefault: Bool
}

enum PaymentMethodType {
    case bankAccount
    case paypal
    case applePay
    case googlePay

    var icon: String {
        switch self {
        case .bankAccount: return "building.columns.fill"
        case .paypal: return "p.circle.fill"
        case .applePay: return "applelogo"
        case .googlePay: return "g.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .bankAccount: return .blue
        case .paypal: return .indigo
        case .applePay: return .black
        case .googlePay: return .green
        }
    }
}

// MARK: - Payment Card Model

struct PaymentCard: Identifiable {
    let id = UUID()
    let brand: CardBrand
    let lastFour: String
    let holderName: String
    let expiryDate: String
    let isDefault: Bool
}

enum CardBrand {
    case visa
    case mastercard
    case amex
    case discover

    var icon: String {
        switch self {
        case .visa: return "creditcard.fill"
        case .mastercard: return "creditcard.fill"
        case .amex: return "creditcard.fill"
        case .discover: return "creditcard.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .visa: return [Color.blue, Color.indigo]
        case .mastercard: return [Color.orange, Color.red]
        case .amex: return [Color.green, Color.teal]
        case .discover: return [Color.orange, Color.yellow]
        }
    }
}

#Preview {
    WalletView(
        user: User(
            id: "test",
            email: "test@example.com",
            name: "Test User",
            walletAddress: "ABC123XYZ789ABC123XYZ789ABC123XYZ789ABC123XYZ789"
        )
    )
}
