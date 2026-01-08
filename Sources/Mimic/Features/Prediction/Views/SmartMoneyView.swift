import SwiftUI

/// Smart Money Signals View
/// Shows aggregated positions from top Jupiter Prediction traders
struct SmartMoneyView: View {
    @StateObject private var api = JupiterPredictionAPI.shared
    @State private var selectedCategory: String? = nil

    private let categories = ["All", "crypto", "politics", "sports", "economics"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryChip(
                                title: category == "All" ? "All" : category.capitalized,
                                isSelected: selectedCategory == (category == "All" ? nil : category),
                                action: {
                                    selectedCategory = category == "All" ? nil : category
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)

                if api.isLoading {
                    ProgressView("Loading smart money signals...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = api.error {
                    ErrorView(message: error) {
                        Task { await api.fetchSmartMoneySignals() }
                    }
                } else {
                    SignalsList(
                        signals: filteredSignals,
                        positions: api.smartMoneyPositions
                    )
                }
            }
            .navigationTitle("Smart Money")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { Task { await api.fetchSmartMoneySignals() }}) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            if api.smartMoneyPositions.isEmpty {
                await api.fetchSmartMoneySignals()
            }
        }
    }

    private var filteredSignals: [AggregatedSignal] {
        let signals = api.getAggregatedSignals()
        guard let category = selectedCategory else { return signals }
        return signals.filter { $0.category == category }
    }
}

// MARK: - Signals List

struct SignalsList: View {
    let signals: [AggregatedSignal]
    let positions: [JupiterPosition]

    var body: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    StatCard(
                        title: "Positions",
                        value: "\(positions.count)",
                        icon: "chart.bar.fill"
                    )
                    StatCard(
                        title: "Traders",
                        value: "\(Set(positions.map { $0.owner }).count)",
                        icon: "person.2.fill"
                    )
                    StatCard(
                        title: "Volume",
                        value: formatVolume(positions.reduce(0) { $0 + $1.sizeUsdDouble }),
                        icon: "dollarsign.circle.fill"
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            // Signals Section
            Section("Top Signals") {
                ForEach(signals.prefix(20)) { signal in
                    SignalRow(signal: signal)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await JupiterPredictionAPI.shared.fetchSmartMoneySignals()
        }
    }

    private func formatVolume(_ amount: Double) -> String {
        if amount >= 1000 {
            return "$\(String(format: "%.1fK", amount / 1000))"
        }
        return "$\(String(format: "%.0f", amount))"
    }
}

// MARK: - Signal Row

struct SignalRow: View {
    let signal: AggregatedSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                // Side indicator
                Text(signal.dominantSide)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(signal.dominantSide == "YES" ? Color.green : Color.red)
                    .clipShape(Capsule())

                Spacer()

                // Category
                Text(signal.category.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Event Title
            Text(signal.eventTitle)
                .font(.headline)
                .lineLimit(2)

            // Market Title (if different)
            if signal.marketTitle != signal.eventTitle && !signal.marketTitle.isEmpty {
                Text(signal.marketTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Stats
            HStack {
                Label("\(signal.traderCount)", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(signal.formattedSize)
                    .font(.subheadline.bold())

                Text("@")
                    .foregroundStyle(.secondary)

                Text(signal.formattedPrice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Confidence bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    Rectangle()
                        .fill(signal.dominantSide == "YES" ? Color.green : Color.red)
                        .frame(width: geometry.size.width * signal.confidence, height: 4)
                }
                .clipShape(Capsule())
            }
            .frame(height: 4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .clipShape(Capsule())
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SmartMoneyView()
}
