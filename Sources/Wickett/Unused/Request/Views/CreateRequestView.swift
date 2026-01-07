import SwiftUI

struct CreateRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PaymentRequestViewModel()
    
    let user: User
    
    @State private var showRequestCreated = false
    @State private var showRecipientSearch = false
    @FocusState private var isMemoFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Spacer()
            
            // Main Input Area
            VStack(spacing: 40) {
                // Recipient
                recipientSection

                // Amount
                amountDisplay

                // Memo
                memoField

                // Error Message
                if let error = viewModel.createError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            
            Spacer()
            
            // Action
            actionButton
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            
            // Numpad
            numpad
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(Color(UIColor.systemBackground))
        .sheet(isPresented: $showRecipientSearch) {
            RecipientSearchSheet(viewModel: viewModel, userId: user.walletAddress ?? user.id)
        }
        .sheet(isPresented: $showRequestCreated) {
            if let request = viewModel.createdRequest {
                RequestCreatedView(request: request, qrCodeImage: viewModel.qrCodeImage)
                    .onDisappear {
                        viewModel.resetCreateForm()
                        dismiss()
                    }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        ZStack {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
            
            Text("New Request")
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Recipient Section
    
    private var recipientSection: some View {
        Button(action: { showRecipientSearch = true }) {
            VStack(spacing: 12) {
                ZStack {
                    if let recipient = viewModel.selectedRecipient {
                        // Selected State
                        Circle()
                            .fill(BrandColors.primary.opacity(0.1))
                            .frame(width: 72, height: 72)
                        
                        Text(recipient.displayName.prefix(1).uppercased())
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(BrandColors.primary)
                    } else {
                        // Empty State
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        
                        // Plus Badge
                        Circle()
                            .fill(BrandColors.primary)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 24, y: 24)
                    }
                }
                
                HStack(spacing: 6) {
                    if let recipient = viewModel.selectedRecipient {
                        Text("Requesting from")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(recipient.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    } else {
                        Text("Select Recipient")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Amount Display
    
    private var amountDisplay: some View {
        HStack(alignment: .center, spacing: 4) {
            Text("$")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(viewModel.amount.isEmpty ? .secondary.opacity(0.5) : .primary)
            
            Text(viewModel.amount.isEmpty ? "0" : viewModel.amount)
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(viewModel.amount.isEmpty ? .secondary.opacity(0.5) : .primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(height: 80)
    }
    
    // MARK: - Memo Field
    
    private var memoField: some View {
        HStack {
            Image(systemName: "text.bubble")
                .foregroundColor(.secondary)
            
            TextField("What's this for?", text: $viewModel.memo)
                .focused($isMemoFocused)
                .font(.body)
                .submitLabel(.done)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Action Button
    
    private var actionButton: some View {
        Button(action: {
            Task {
                await viewModel.createRequest()
                if viewModel.createdRequest != nil {
                    showRequestCreated = true
                }
            }
        }) {
            HStack {
                if viewModel.isCreating {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 8)
                }
                
                Text("Send Request")
                    .font(.headline.weight(.semibold))
                
                if !viewModel.isCreating {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isFormValid ? BrandColors.primary : Color(.systemGray5))
            .foregroundColor(isFormValid ? .white : .secondary)
            .cornerRadius(14)
        }
        .disabled(viewModel.isCreating || !isFormValid)
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
            .contentShape(Rectangle()) // Make full area tappable
        }
    }
    
    private func handleNumpadTap(_ key: String) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        switch key {
        case "⌫":
            if !viewModel.amount.isEmpty {
                viewModel.amount.removeLast()
            }
        case ".":
            if !viewModel.amount.contains(".") {
                viewModel.amount += viewModel.amount.isEmpty ? "0." : "."
            }
        default:
            if viewModel.amount.count < 10 {
                if let dotIndex = viewModel.amount.firstIndex(of: ".") {
                    let decimals = viewModel.amount.distance(from: dotIndex, to: viewModel.amount.endIndex) - 1
                    if decimals >= 2 { return }
                }
                viewModel.amount += key
            }
        }
    }
    
    private var isFormValid: Bool {
        guard viewModel.selectedRecipient != nil,
              !viewModel.amount.isEmpty,
              let amount = Decimal(string: viewModel.amount),
              amount > 0 else {
            return false
        }
        return true
    }
}

// MARK: - Wickett Team Contacts (for testing)

enum WickettTeamContacts {
    static let contacts: [UserSearchResult] = [
        UserSearchResult(
            userId: "jakey",
            displayName: "Jakey",
            username: "jakey",
            walletAddress: "JAKEY_WALLET_ADDRESS" // TODO: Replace with actual wallet
        ),
        UserSearchResult(
            userId: "mike",
            displayName: "Mike",
            username: "mike",
            walletAddress: "MIKE_WALLET_ADDRESS" // TODO: Replace with actual wallet
        ),
        UserSearchResult(
            userId: "admin",
            displayName: "Wickett Admin",
            username: "admin",
            walletAddress: "ADMIN_WALLET_ADDRESS" // TODO: Replace with actual wallet
        )
    ]
}

// MARK: - Recipient Search Sheet

struct RecipientSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PaymentRequestViewModel
    let userId: String

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Name, @username, or address", text: $viewModel.recipientSearchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onChange(of: viewModel.recipientSearchQuery) { newValue in
                            Task { await viewModel.searchForRecipients() }
                        }

                    if !viewModel.recipientSearchQuery.isEmpty {
                        Button(action: { viewModel.recipientSearchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding()

                List {
                    if !viewModel.searchResults.isEmpty {
                        Section("Results") {
                            ForEach(viewModel.searchResults, id: \.userId) { result in
                                RecipientRow(
                                    name: result.displayName,
                                    detail: result.username != nil ? "@\(result.username!)" : result.walletAddress,
                                    initials: String(result.displayName.prefix(1)),
                                    action: { selectRecipient(result) }
                                )
                            }
                        }
                    } else if viewModel.isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        // Wickett Team (always show for testing)
                        Section("Wickett Team") {
                            ForEach(WickettTeamContacts.contacts, id: \.userId) { contact in
                                RecipientRow(
                                    name: contact.displayName,
                                    detail: "@\(contact.username ?? "")",
                                    initials: String(contact.displayName.prefix(1)),
                                    action: { selectRecipient(contact) }
                                )
                            }
                        }

                        if !viewModel.recentRecipients.isEmpty {
                            Section("Recent") {
                                ForEach(viewModel.recentRecipients) { recipient in
                                    RecipientRow(
                                        name: recipient.displayName ?? "Unknown",
                                        detail: recipient.formattedAddress,
                                        initials: recipient.initials,
                                        action: { selectRecent(recipient) }
                                    )
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Recipient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.loadRecentRecipients(userId: userId)
            }
        }
    }
    
    private func selectRecipient(_ result: UserSearchResult) {
        viewModel.selectedRecipient = result
        viewModel.searchResults = []
        viewModel.recipientSearchQuery = ""
        dismiss()
    }
    
    private func selectRecent(_ recipient: RecentRecipient) {
        viewModel.selectedRecipient = UserSearchResult(
            userId: recipient.id,
            displayName: recipient.displayName ?? "Unknown",
            username: nil,
            walletAddress: recipient.address
        )
        dismiss()
    }
}

struct RecipientRow: View {
    let name: String
    let detail: String
    let initials: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(initials.uppercased())
                            .font(.headline)
                            .foregroundColor(.primary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    CreateRequestView(user: User(
        id: "test",
        email: "test@example.com",
        name: "Test User",
        walletAddress: "TestWallet123",
        username: nil
    ))
}
