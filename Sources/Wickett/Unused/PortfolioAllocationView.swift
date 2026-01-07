import SwiftUI

struct PortfolioAllocationView: View {
    @Binding var portfolio: [PortfolioAllocation]
    let onSave: ([PortfolioAllocation]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var editablePortfolio: [PortfolioAllocation] = []
    @State private var validationError: String?
    @State private var viewMode: ViewMode = .selection

    enum ViewMode {
        case selection
        case suggestedPreview
        case editor
    }

    enum PortfolioPreset: CaseIterable {
        case crypto
        case diversified
        
        var name: String {
            switch self {
            case .crypto: return "Crypto Only"
            case .diversified: return "Gold & Stocks"
            }
        }
        
        var description: String {
            switch self {
            case .crypto: return "Exposure to top crypto assets on Solana."
            case .diversified: return "Balanced mix of crypto, gold, and tech stocks."
            }
        }
        
        var icon: String {
            switch self {
            case .crypto: return "bitcoinsign.circle.fill"
            case .diversified: return "chart.pie.fill"
            }
        }
        
        var allocations: [PortfolioAllocation] {
            switch self {
            case .crypto:
                return [
                    PortfolioAllocation(token: SupportedToken.sol.mint, symbol: "SOL", percentage: 25),
                    PortfolioAllocation(token: SupportedToken.wbtc.mint, symbol: "wBTC", percentage: 25),
                    PortfolioAllocation(token: SupportedToken.weth.mint, symbol: "wETH", percentage: 25),
                    PortfolioAllocation(token: SupportedToken.zec.mint, symbol: "ZEC", percentage: 25)
                ]
            case .diversified:
                return [
                    PortfolioAllocation(token: SupportedToken.sol.mint, symbol: "SOL", percentage: 40),
                    PortfolioAllocation(token: SupportedToken.gold.mint, symbol: "GOLD", percentage: 20),
                    PortfolioAllocation(token: SupportedToken.aapl.mint, symbol: "AAPL", percentage: 20),
                    PortfolioAllocation(token: SupportedToken.tsla.mint, symbol: "TSLA", percentage: 20)
                ]
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                switch viewMode {
                case .selection:
                    StrategySelectionView(
                        onSelectSuggested: { withAnimation { viewMode = .suggestedPreview } },
                        onSelectManual: {
                            editablePortfolio = []
                            withAnimation { viewMode = .editor }
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    
                case .suggestedPreview:
                    PresetSelectionView(
                        onSelect: { preset in
                            applyPreset(preset)
                            withAnimation { viewMode = .editor }
                        },
                        onBack: { withAnimation { viewMode = .selection } }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    
                case .editor:
                    editorView
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.body)
                }
                
                if viewMode == .editor {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Reset") {
                            withAnimation {
                                editablePortfolio = []
                                viewMode = .selection
                            }
                        }
                        .font(.body)
                        .foregroundColor(.red)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewMode)
            .onAppear {
                if !portfolio.isEmpty {
                    editablePortfolio = portfolio
                    viewMode = .editor
                }
            }
        }
    }
    
    // MARK: - Subviews for Flows
    
    struct StrategySelectionView: View {
        let onSelectSuggested: () -> Void
        let onSelectManual: () -> Void

        var body: some View {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Text("Setup Your Portfolio")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    
                    Text("Choose how you want to allocate your incoming payments.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 16) {
                    StrategyCard(
                        icon: "star.circle.fill",
                        iconColor: .yellow,
                        title: "Suggested Strategies",
                        description: "Pick from expert-curated sets",
                        action: onSelectSuggested
                    )

                    StrategyCard(
                        icon: "slider.horizontal.3",
                        iconColor: BrandColors.primary,
                        title: "Build Your Own",
                        description: "Select individual tokens manually",
                        action: onSelectManual
                    )
                }
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
        }
    }
    
    struct StrategyCard: View {
        let icon: String
        let iconColor: Color
        let title: String
        let description: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(iconColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }
    
    struct PresetSelectionView: View {
        let onSelect: (PortfolioPreset) -> Void
        let onBack: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.body)
                    }
                    Spacer()
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("Choose a Strategy")
                                .font(.largeTitle.weight(.bold))
                            Text("Select a template to start with")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical)

                        ForEach(PortfolioPreset.allCases, id: \.self) { preset in
                            Button(action: { onSelect(preset) }) {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: preset.icon)
                                            .font(.title2)
                                            .foregroundColor(BrandColors.primary)
                                        Text(preset.name)
                                            .font(.title3.weight(.bold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }

                                    Text(preset.description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)

                                    // Mini allocation preview
                                    FlowLayout(spacing: 8) {
                                        ForEach(preset.allocations.prefix(4)) { item in
                                            Text("\(item.symbol) \(Int(item.percentage))%")
                                                .font(.caption.weight(.medium))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color(.tertiarySystemFill))
                                                .cornerRadius(8)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                }
                                .padding(20)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    // Very simple flow layout for tags
    struct FlowLayout: Layout {
        var spacing: CGFloat = 8
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let result = flow(proposal: proposal, subviews: subviews, perform: false)
            return result.size
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            flow(proposal: proposal, subviews: subviews, perform: true, in: bounds)
        }
        
        @discardableResult
        func flow(proposal: ProposedViewSize, subviews: Subviews, perform: Bool, in bounds: CGRect = .zero) -> (size: CGSize, offsets: [CGPoint]) {
            var size: CGSize = .zero
            var offsets: [CGPoint] = []
            var x: CGFloat = 0
            var y: CGFloat = 0
            let maxWidth = proposal.width ?? .infinity
            var maxHeight: CGFloat = 0
            
            for subview in subviews {
                let subSize = subview.sizeThatFits(.unspecified)
                if x + subSize.width > maxWidth {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }
                
                if perform {
                    subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .unspecified)
                }
                
                maxHeight = max(maxHeight, subSize.height)
                x += subSize.width + spacing
                size.width = max(size.width, x)
                size.height = max(size.height, y + subSize.height)
            }
            
            return (size, offsets)
        }
    }

    // MARK: - Editor View (Main Logic)

    private var editorView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Visual Ring Chart
                    ZStack {
                        if editablePortfolio.isEmpty {
                            Circle()
                                .stroke(Color.secondary.opacity(0.1), lineWidth: 20)
                                .frame(width: 200, height: 200)
                            Text("Empty")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        } else {
                            PortfolioRingChart(portfolio: editablePortfolio)
                                .frame(width: 200, height: 200)
                            
                            VStack(spacing: 4) {
                                Text("\(Int(totalPercentage))%")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(isValidTotal ? .primary : .red)
                                Text("Allocated")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 24)

                    // List of Allocations
                    VStack(spacing: 16) {
                        ForEach($editablePortfolio) { $allocation in
                            AllocationRow(allocation: $allocation, onDelete: {
                                removeToken(allocation)
                            })
                        }
                        
                        // Add Token Button
                        Menu {
                            ForEach(SupportedToken.allCases, id: \.self) { token in
                                if !editablePortfolio.contains(where: { $0.symbol == token.rawValue.uppercased() }) {
                                    Button(action: { addToken(token) }) {
                                        HStack {
                                            Text(token.rawValue.uppercased())
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Add Asset")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(BrandColors.primary)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(BrandColors.primary.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }

            // Sticky Footer
            VStack(spacing: 16) {
                if let error = validationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Button(action: handleSave) {
                    Text("Save Portfolio")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(isValidTotal ? BrandColors.primary : Color(.systemGray4))
                        .cornerRadius(14)
                }
                .disabled(!isValidTotal)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -4)
        }
        .navigationTitle("Edit Portfolio")
    }

    // MARK: - Helpers

    private var totalPercentage: Double {
        editablePortfolio.reduce(0) { $0 + $1.percentage }
    }

    private var isValidTotal: Bool {
        abs(totalPercentage - 100.0) < 0.01
    }
    
    private func applyPreset(_ preset: PortfolioPreset) {
        editablePortfolio = preset.allocations
    }

    private func addToken(_ token: SupportedToken) {
        let newAllocation = PortfolioAllocation(
            token: token.mint,
            symbol: token.rawValue.uppercased(),
            percentage: 0
        )
        editablePortfolio.append(newAllocation)
    }

    private func removeToken(_ allocation: PortfolioAllocation) {
        editablePortfolio.removeAll { $0.id == allocation.id }
    }

    private func handleSave() {
        let validation = DelegationManager.shared.validatePortfolio(editablePortfolio)
        if validation.isValid {
            validationError = nil
            onSave(editablePortfolio)
        } else {
            validationError = validation.error
        }
    }
}

// MARK: - Subviews

struct AllocationRow: View {
    @Binding var allocation: PortfolioAllocation
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                // Token Info
                HStack(spacing: 12) {
                    tokenImage(for: allocation.symbol)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .background(Circle().fill(Color(.systemGray6)))
                    
                    Text(allocation.symbol)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Percentage Display
                Text("\(Int(allocation.percentage))%")
                    .font(.headline)
                    .foregroundColor(BrandColors.primary)
                    .frame(width: 50, alignment: .trailing)
                
                // Delete
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .padding(.leading, 8)
            }

            // Standard Slider
            Slider(value: $allocation.percentage, in: 0...100, step: 5)
                .tint(BrandColors.primary)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct PortfolioRingChart: View {
    let portfolio: [PortfolioAllocation]
    
    var body: some View {
        Canvas { context, size in
            let total = portfolio.reduce(0) { $0 + $1.percentage }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 20
            let strokeWidth: CGFloat = 20
            
            // Draw background ring
            let backgroundPath = Path { p in
                p.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            }
            context.stroke(backgroundPath, with: .color(Color(.systemGray5)), lineWidth: strokeWidth)
            
            var startAngle = Angle.degrees(-90)
            
            for (index, item) in portfolio.enumerated() {
                let angle = Angle.degrees(360 * (item.percentage / 100))
                let endAngle = startAngle + angle
                
                let path = Path { p in
                    p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                }
                
                context.stroke(
                    path,
                    with: .color(color(for: index)),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                
                startAngle = endAngle
            }
        }
    }
    
    func color(for index: Int) -> Color {
        let colors: [Color] = [
            BrandColors.primary,
            Color.purple,
            Color.orange,
            Color.green,
            Color.pink,
            Color.blue
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Asset Helper

private func tokenImage(for symbol: String) -> some View {
    Group {
        if let image = loadAssetImage(for: symbol) {
            image
                .resizable()
        } else {
            // Fallback
            ZStack {
                Circle().fill(BrandColors.primary.opacity(0.1))
                Text(symbol.prefix(1)).font(.caption).bold()
                    .foregroundColor(BrandColors.primary)
            }
        }
    }
}

private func loadAssetImage(for symbol: String) -> Image? {
    switch symbol.uppercased() {
    case "SOL": return Image("TokenSOL")
    case "USDC": return Image("TokenUSDC")
    case "BONK": return Image("TokenBONK")
    case "JUP": return Image("TokenJUP")
    case "WETH": return Image("TokenWETH")
    case "WBTC": return Image("TokenWBTC")
    case "ZEC": return Image("TokenZEC")
    case "GOLD": return Image("TokenGOLD")
    case "AAPL": return Image("TokenAAPLX")
    case "TSLA": return Image("TokenTSLAX")
    case "NVDA": return Image("TokenNVDAX")
    case "MSFT": return Image("TokenMSFTX")
    case "AMZN": return Image("TokenAMZNX")
    default: return nil
    }
}

#Preview {
    PortfolioAllocationView(portfolio: .constant([]), onSave: { _ in })
}
