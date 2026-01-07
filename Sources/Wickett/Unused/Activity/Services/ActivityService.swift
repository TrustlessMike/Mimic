import Foundation
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Wickett", category: "ActivityService")

/// Service for fetching user activity from Firebase
@MainActor
class ActivityService: ObservableObject {
    static let shared = ActivityService()

    @Published var activities: [ActivityItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: ActivityError?
    @Published var hasMore = false
    @Published var isRefreshingInBackground = false

    private let firebaseClient = FirebaseCallableClient.shared

    // Pagination
    private let initialLimit = 10
    private let pageSize = 20
    private var currentOffset = 0

    // Local persistence
    private let cacheKey = "cached_activities"

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    /// Fetch user activity
    /// Always shows cached data immediately, then fetches fresh data in background
    func fetchActivity(forceRefresh: Bool = false) async {
        // Already fetching - skip
        if isLoading || isRefreshingInBackground {
            logger.info("⏭️ Already loading activity")
            return
        }

        // If we have cached data, show it and refresh in background
        if !activities.isEmpty {
            logger.info("📋 Showing \(self.activities.count) cached items, refreshing in background...")
            isRefreshingInBackground = true
            await fetchFromServer()
            isRefreshingInBackground = false
            return
        }

        // No cached data - show loading spinner
        isLoading = true
        error = nil
        await fetchFromServer()
        isLoading = false
    }

    /// Fetch activities from server
    private func fetchFromServer() async {
        currentOffset = 0

        logger.info("📋 Fetching user activity (limit: \(self.initialLimit))...")

        do {
            let result = try await firebaseClient.call("getUserActivity", data: [
                "limit": self.initialLimit,
                "offset": 0
            ])

            guard let resultData = result.data as? [String: Any],
                  let activitiesArray = resultData["activities"] as? [[String: Any]] else {
                throw ActivityError.invalidResponse
            }

            let parsedActivities = activitiesArray.compactMap { parseActivityItem($0) }
            let hasMoreFlag = resultData["hasMore"] as? Bool ?? (parsedActivities.count >= initialLimit)

            self.activities = parsedActivities
            self.hasMore = hasMoreFlag
            self.currentOffset = parsedActivities.count

            // Persist to disk
            saveToDisk()

            logger.info("✅ Fetched \(parsedActivities.count) activity items, hasMore: \(hasMoreFlag)")

        } catch {
            logger.error("❌ Failed to fetch activity: \(error.localizedDescription)")
            self.error = .fetchFailed(error.localizedDescription)
        }
    }

    /// Force refresh activity
    func refresh() async {
        isLoading = activities.isEmpty
        isRefreshingInBackground = !activities.isEmpty
        error = nil
        await fetchFromServer()
        isLoading = false
        isRefreshingInBackground = false
    }

    /// Load more activities (pagination)
    func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }

        isLoadingMore = true

        logger.info("📋 Loading more activity (offset: \(self.currentOffset), limit: \(self.pageSize))...")

        do {
            let result = try await firebaseClient.call("getUserActivity", data: [
                "limit": self.pageSize,
                "offset": self.currentOffset
            ])

            guard let resultData = result.data as? [String: Any],
                  let activitiesArray = resultData["activities"] as? [[String: Any]] else {
                throw ActivityError.invalidResponse
            }

            let parsedActivities = activitiesArray.compactMap { parseActivityItem($0) }
            let hasMoreFlag = resultData["hasMore"] as? Bool ?? (parsedActivities.count >= pageSize)

            self.activities.append(contentsOf: parsedActivities)
            self.hasMore = hasMoreFlag
            self.currentOffset += parsedActivities.count
            self.isLoadingMore = false

            logger.info("✅ Loaded \(parsedActivities.count) more items, total: \(self.activities.count)")

        } catch {
            logger.error("❌ Failed to load more activity: \(error.localizedDescription)")
            self.isLoadingMore = false
        }
    }

    /// Clear cache (e.g., on logout)
    func clear() {
        activities = []
        hasMore = false
        error = nil
        clearDiskCache()
        logger.info("🧹 Cleared activity cache")
    }

    /// Convert activities to Transaction objects for existing UI
    func getTransactions() -> [Transaction] {
        return activities.map { $0.toTransaction() }
    }

    /// Filter activities by type
    func filteredActivities(filter: TransactionFilter) -> [ActivityItem] {
        guard filter != .all else { return activities }

        return activities.filter { activity in
            switch filter {
            case .all:
                return true
            case .deposits:
                return activity.type == .paymentReceived || activity.type == .requestReceived
            case .payments:
                return activity.type == .paymentSent
            case .withdrawals:
                return activity.type == .requestSent
            case .conversions:
                return activity.type == .autoConvert
            }
        }
    }

    // MARK: - Private Helpers

    private func parseActivityItem(_ data: [String: Any]) -> ActivityItem? {
        guard let id = data["id"] as? String,
              let typeString = data["type"] as? String,
              let type = ActivityType(rawValue: typeString),
              let title = data["title"] as? String,
              let subtitle = data["subtitle"] as? String,
              let amount = data["amount"] as? Double,
              let statusString = data["status"] as? String,
              let status = ActivityStatus(rawValue: statusString),
              let icon = data["icon"] as? String else {
            logger.warning("⚠️ Failed to parse activity item: \(data)")
            return nil
        }

        // Skip zero-amount and spam transactions (dust attacks typically < $0.01)
        guard amount >= 0.01 else {
            logger.info("⏭️ Skipping zero/spam activity: \(id) (amount: $\(amount))")
            return nil
        }

        // Parse timestamp - handle both Firestore Timestamp and epoch milliseconds
        let timestamp: Date
        if let timestampData = data["timestamp"] as? [String: Any],
           let seconds = timestampData["_seconds"] as? Int64 {
            // Firestore Timestamp format
            timestamp = Date(timeIntervalSince1970: TimeInterval(seconds))
        } else if let epochMillis = data["timestamp"] as? Int64 {
            // Epoch milliseconds
            timestamp = Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1000)
        } else if let epochSeconds = data["timestamp"] as? Double {
            // Epoch seconds (double)
            timestamp = Date(timeIntervalSince1970: epochSeconds)
        } else {
            logger.warning("⚠️ Could not parse timestamp for activity \(id)")
            timestamp = Date()
        }

        return ActivityItem(
            id: id,
            type: type,
            title: title,
            subtitle: subtitle,
            amount: amount,
            timestamp: timestamp,
            status: status,
            icon: icon
        )
    }

    // MARK: - Disk Persistence

    /// Load cached activities from disk on init
    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            logger.info("📋 No cached activities on disk")
            return
        }

        do {
            let cached = try JSONDecoder().decode([ActivityItem].self, from: data)
            self.activities = cached
            logger.info("📋 Loaded \(cached.count) cached activities from disk")
        } catch {
            logger.error("❌ Failed to decode cached activities: \(error.localizedDescription)")
        }
    }

    /// Save activities to disk
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(activities)
            UserDefaults.standard.set(data, forKey: cacheKey)
            logger.info("💾 Saved \(self.activities.count) activities to disk")
        } catch {
            logger.error("❌ Failed to encode activities for disk: \(error.localizedDescription)")
        }
    }

    /// Clear disk cache
    private func clearDiskCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        logger.info("🧹 Cleared disk cache")
    }
}

// MARK: - Errors

enum ActivityError: LocalizedError {
    case fetchFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to load activity: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
