import SwiftUI
import Charts

struct TokenDetailView: View {
    let balance: TokenBalance

    @Environment(\.dismiss) private var dismiss
    @State private var priceHistory: [(Date, Decimal)] = []
    @State private var isLoading = true
    @State private var selectedTimeframe: PriceTimeframe = .week
    @State private var selectedPrice: Decimal?
    @State private var selectedDate: Date?

    private let priceFeedService = PriceFeedService.shared

    enum PriceTimeframe: String, CaseIterable {
        case day = "1D"
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"

        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }

        var label: String {
            switch self {
            case .day: return "Today"
            case .week: return "This Week"
            case .month: return "This Month"
            case .threeMonths: return "3 Months"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Big price display (hero element)
                    priceDisplay

                    // Simple chart
                    chartSection

                    // Timeframe selector
                    timeframeSelector

                    // Your holdings (compact)
                    holdingsSection

                    Spacer(minLength: 120)
                }
                .padding(.top, 8)
            }

            // Fixed Swap button at bottom
            swapButton
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    TokenImageView(token: balance.token, size: 24)
                    Text(balance.token.name)
                        .font(.headline)
                }
            }
        }
        .task {
            await loadPriceHistory()
        }
        .onChange(of: selectedTimeframe) { _ in
            Task {
                await loadPriceHistory()
            }
        }
    }

    // MARK: - Price Display

    private var priceDisplay: some View {
        VStack(spacing: 8) {
            // Current or selected price
            Text(displayPrice)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .contentTransition(.numericText())

            // Change indicator
            if let change = periodChange {
                HStack(spacing: 6) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.subheadline.weight(.semibold))

                    Text(formatChange(change))
                        .font(.subheadline.weight(.semibold))

                    Text(selectedTimeframe.label)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(change >= 0 ? .green : .red)
            }

            // Selected date if scrubbing
            if let date = selectedDate {
                Text(formatSelectedDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var displayPrice: String {
        if let selected = selectedPrice {
            return formatCurrency(selected)
        }
        return formatCurrency(balance.usdPrice)
    }

    private var periodChange: Decimal? {
        if !priceHistory.isEmpty {
            let startPrice = priceHistory.first?.1 ?? 0
            let endPrice = priceHistory.last?.1 ?? 0
            guard startPrice > 0 else { return nil }
            return ((endPrice - startPrice) / startPrice) * 100
        }
        return balance.change24h
    }

    // MARK: - Chart Section

    // Computed Y-axis domain for relative scaling
    private var chartYDomain: ClosedRange<Double> {
        let prices = priceHistory.map { NSDecimalNumber(decimal: $0.1).doubleValue }
        guard let minPrice = prices.min(), let maxPrice = prices.max() else {
            return 0...1
        }

        // Add 10% padding above and below for visual clarity
        let range = maxPrice - minPrice
        let padding = max(range * 0.1, maxPrice * 0.02) // At least 2% of price if range is tiny

        return (minPrice - padding)...(maxPrice + padding)
    }

    private var chartSection: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .frame(height: 180)
            } else if priceHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No chart data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            } else {
                // Clean, edge-to-edge chart like Robinhood
                Chart {
                    ForEach(priceHistory.indices, id: \.self) { index in
                        let point = priceHistory[index]
                        LineMark(
                            x: .value("Date", point.0),
                            y: .value("Price", NSDecimalNumber(decimal: point.1).doubleValue)
                        )
                        .foregroundStyle(chartColor)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: chartYDomain)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x
                                        if let date: Date = proxy.value(atX: x) {
                                            if let closest = priceHistory.min(by: {
                                                abs($0.0.timeIntervalSince(date)) < abs($1.0.timeIntervalSince(date))
                                            }) {
                                                selectedDate = closest.0
                                                selectedPrice = closest.1
                                                // Haptic feedback
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedPrice = nil
                                        selectedDate = nil
                                    }
                            )
                    }
                }
                .frame(height: 200)
                .clipped()
            }
        }
    }

    private var chartColor: Color {
        guard let change = periodChange else { return BrandColors.primary }
        return change >= 0 ? .green : .red
    }

    // MARK: - Timeframe Selector

    private var timeframeSelector: some View {
        HStack(spacing: 0) {
            ForEach(PriceTimeframe.allCases, id: \.self) { timeframe in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimeframe = timeframe
                    }
                }) {
                    Text(timeframe.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTimeframe == timeframe ? BrandColors.primary : Color.clear)
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Holdings Section

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Holdings")
                .font(.headline)
                .padding(.horizontal)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(balance.displayAmount)
                        .font(.title3.weight(.bold))
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(balance.displayUSD)
                        .font(.title3.weight(.bold))
                    Text("Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Swap Button

    @State private var showSwap = false

    private var swapButton: some View {
        Button(action: {
            showSwap = true
        }) {
            Text("Swap \(balance.token.symbol)")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(BrandColors.primary)
                .foregroundColor(.white)
                .cornerRadius(14)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100) // Tab bar spacing
        .background(Color(.systemBackground))
        .sheet(isPresented: $showSwap) {
            SwapView(preselectedFromToken: balance.token)
        }
    }

    // MARK: - Helpers

    private func loadPriceHistory() async {
        isLoading = true

        do {
            let history = try await priceFeedService.fetchHistoricalPrices(
                for: balance.token.symbol,
                days: selectedTimeframe.days
            )
            priceHistory = history
            print("📈 Loaded \(history.count) price points for \(balance.token.symbol)")
        } catch {
            print("❌ Failed to load chart for \(balance.token.symbol): \(error)")
            priceHistory = []
        }

        isLoading = false
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"

        if value < 1 {
            formatter.maximumFractionDigits = 4
        } else {
            formatter.maximumFractionDigits = 2
        }

        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private func formatChange(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        return formatter.string(from: (value / 100) as NSDecimalNumber) ?? "0%"
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedTimeframe {
        case .day:
            formatter.dateFormat = "h:mm a"
        case .week:
            formatter.dateFormat = "EEEE, h:mm a"
        case .month, .threeMonths:
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        TokenDetailView(
            balance: TokenBalance(
                id: "sol",
                token: TokenRegistry.SOL,
                lamports: 1_000_000_000,
                usdPrice: 133.17,
                change24h: 4.27,
                lastUpdated: Date()
            )
        )
    }
}
