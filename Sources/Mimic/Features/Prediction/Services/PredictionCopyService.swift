import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "PredictionCopy")

/// Pending copy trade awaiting user action
struct PendingCopyTrade: Identifiable, Codable {
    let id: String
    let userId: String
    let userWalletAddress: String
    let betId: String
    let trackedWallet: String
    var trackedWalletNickname: String?
    let marketAddress: String
    var marketTitle: String?
    let direction: String            // "YES" or "NO"
    let originalAmount: Double
    let originalPrice: Double
    let suggestedAmount: Double
    var status: String               // "pending", "executed", "expired", "skipped"
    let createdAt: Date
    let expiresAt: Date
    var executedAt: Date?
    var executedSignature: String?
}

/// Prediction delegation configuration
struct PredictionDelegation: Codable {
    let id: String
    let status: String  // "active", "revoked", "expired"
    let maxCopyAmountUsd: Double
    let copyPercentage: Double
    let minBetSizeUsd: Double
    let expiresAt: Date
    let totalCopiesExecuted: Int
    let totalVolumeUsd: Double
}

/// Service for managing prediction market copy trading
@MainActor
class PredictionCopyService: ObservableObject {
    static let shared = PredictionCopyService()

    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    @Published var trackedPredictors: [TrackedPredictor] = []
    @Published var pendingCopies: [PendingCopyTrade] = []
    @Published var isLoading = false
    @Published var error: String?

    // Delegation state
    @Published var delegationActive = false
    @Published var delegation: PredictionDelegation?
    @Published var isDelegationLoading = false

    private var predictorsListener: ListenerRegistration?
    private var pendingListener: ListenerRegistration?
    private var delegationListener: ListenerRegistration?

    private init() {}

    deinit {
        predictorsListener?.remove()
        pendingListener?.remove()
        delegationListener?.remove()
    }

    // MARK: - Load Tracked Predictors

    func loadTrackedPredictors() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isLoading = true
        error = nil

        do {
            let snapshot = try await db.collection("tracked_predictors")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            trackedPredictors = snapshot.documents.compactMap { doc in
                parseTrackedPredictor(doc)
            }

            logger.info("Loaded \(self.trackedPredictors.count) tracked predictors")
        } catch {
            logger.error("Failed to load tracked predictors: \(error.localizedDescription)")
            self.error = "Failed to load tracked predictors"
        }

        isLoading = false
    }

    /// Start real-time listener for tracked predictors
    func startPredictorsListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        predictorsListener?.remove()

        predictorsListener = db.collection("tracked_predictors")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    logger.error("Predictors listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    self.trackedPredictors = documents.compactMap { doc in
                        self.parseTrackedPredictor(doc)
                    }
                }
            }
    }

    func stopPredictorsListener() {
        predictorsListener?.remove()
        predictorsListener = nil
    }

    // MARK: - Add/Remove Tracked Predictor

    func addTrackedPredictor(
        address: String,
        nickname: String?,
        autoCopyEnabled: Bool = false,
        copyPercentage: Double = 5,
        maxCopyAmountUsd: Double = 50,
        minBetSizeUsd: Double = 5
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw PredictionCopyError.notAuthenticated
        }

        // Check limit (max 5 predictors)
        if trackedPredictors.count >= 5 {
            throw PredictionCopyError.limitReached
        }

        // Check if already tracking
        if trackedPredictors.contains(where: { $0.walletAddress == address }) {
            throw PredictionCopyError.alreadyTracking
        }

        isLoading = true
        error = nil

        do {
            let docRef = db.collection("tracked_predictors").document()

            try await docRef.setData([
                "userId": userId,
                "walletAddress": address,
                "nickname": nickname ?? "",
                "autoCopyEnabled": autoCopyEnabled,
                "copyPercentage": copyPercentage,
                "maxCopyAmountUsd": maxCopyAmountUsd,
                "minBetSizeUsd": minBetSizeUsd,
                "createdAt": FieldValue.serverTimestamp(),
            ])

            logger.info("Added tracked predictor: \(address)")
            await loadTrackedPredictors()
        } catch {
            logger.error("Failed to add tracked predictor: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }

        isLoading = false
    }

    func removeTrackedPredictor(_ predictor: TrackedPredictor) async throws {
        isLoading = true
        error = nil

        do {
            try await db.collection("tracked_predictors").document(predictor.id).delete()
            trackedPredictors.removeAll { $0.id == predictor.id }
            logger.info("Removed tracked predictor: \(predictor.walletAddress)")
        } catch {
            logger.error("Failed to remove tracked predictor: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isLoading = false
            throw error
        }

        isLoading = false
    }

    // MARK: - Toggle Auto-Copy

    func toggleAutoCopy(for predictor: TrackedPredictor, enabled: Bool) async {
        guard let index = trackedPredictors.firstIndex(where: { $0.id == predictor.id }) else { return }

        do {
            try await db.collection("tracked_predictors").document(predictor.id).updateData([
                "autoCopyEnabled": enabled,
                "updatedAt": FieldValue.serverTimestamp()
            ])

            trackedPredictors[index].autoCopyEnabled = enabled
            logger.info("Auto-copy \(enabled ? "enabled" : "disabled") for \(predictor.walletAddress)")
        } catch {
            logger.error("Failed to toggle auto-copy: \(error.localizedDescription)")
            self.error = "Failed to update auto-copy setting"
        }
    }

    func updateCopySettings(
        for predictor: TrackedPredictor,
        copyPercentage: Double? = nil,
        maxCopyAmountUsd: Double? = nil,
        minBetSizeUsd: Double? = nil
    ) async {
        guard let index = trackedPredictors.firstIndex(where: { $0.id == predictor.id }) else { return }

        var updates: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]

        if let percentage = copyPercentage {
            updates["copyPercentage"] = percentage
            trackedPredictors[index].copyPercentage = percentage
        }
        if let maxAmount = maxCopyAmountUsd {
            updates["maxCopyAmountUsd"] = maxAmount
            trackedPredictors[index].maxCopyAmountUsd = maxAmount
        }
        if let minBet = minBetSizeUsd {
            updates["minBetSizeUsd"] = minBet
            trackedPredictors[index].minBetSizeUsd = minBet
        }

        do {
            try await db.collection("tracked_predictors").document(predictor.id).updateData(updates)
            logger.info("Updated copy settings for \(predictor.walletAddress)")
        } catch {
            logger.error("Failed to update copy settings: \(error.localizedDescription)")
            self.error = "Failed to update settings"
        }
    }

    // MARK: - Pending Copy Trades

    func loadPendingCopies() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            let snapshot = try await db.collection("pending_copy_trades")
                .whereField("userId", isEqualTo: userId)
                .whereField("status", isEqualTo: "pending")
                .order(by: "createdAt", descending: true)
                .limit(to: 10)
                .getDocuments()

            pendingCopies = snapshot.documents.compactMap { doc in
                parsePendingCopyTrade(doc)
            }

            logger.info("Loaded \(self.pendingCopies.count) pending copies")
        } catch {
            logger.error("Failed to load pending copies: \(error.localizedDescription)")
        }
    }

    /// Start real-time listener for pending copies
    func startPendingListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        pendingListener?.remove()

        pendingListener = db.collection("pending_copy_trades")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    logger.error("Pending listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    self.pendingCopies = documents.compactMap { doc in
                        self.parsePendingCopyTrade(doc)
                    }.filter { $0.expiresAt > Date() } // Filter expired
                }
            }
    }

    func stopPendingListener() {
        pendingListener?.remove()
        pendingListener = nil
    }

    /// Skip a pending copy trade
    func skipPendingCopy(_ copy: PendingCopyTrade) async {
        do {
            try await db.collection("pending_copy_trades").document(copy.id).updateData([
                "status": "skipped"
            ])
            pendingCopies.removeAll { $0.id == copy.id }
            logger.info("Skipped pending copy: \(copy.id)")
        } catch {
            logger.error("Failed to skip pending copy: \(error.localizedDescription)")
        }
    }

    /// Mark a pending copy as executed
    func markCopyExecuted(_ copy: PendingCopyTrade, signature: String) async {
        do {
            try await db.collection("pending_copy_trades").document(copy.id).updateData([
                "status": "executed",
                "executedAt": FieldValue.serverTimestamp(),
                "executedSignature": signature
            ])
            pendingCopies.removeAll { $0.id == copy.id }
            logger.info("Marked copy executed: \(copy.id)")
        } catch {
            logger.error("Failed to mark copy executed: \(error.localizedDescription)")
        }
    }

    /// Build Jupiter Prediction Market URL for manual execution
    func buildJupiterUrl(for copy: PendingCopyTrade) -> URL? {
        let urlString = "https://jup.ag/prediction/\(copy.marketAddress)"
        return URL(string: urlString)
    }

    // MARK: - Delegation Management

    /// Load current delegation status
    func loadDelegationStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            // Check user document for delegation status
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data() ?? [:]

            delegationActive = userData["predictionDelegationActive"] as? Bool ?? false

            if delegationActive, let delegationId = userData["predictionDelegationId"] as? String {
                // Load delegation details
                let delegationDoc = try await db.collection("users")
                    .document(userId)
                    .collection("prediction_delegations")
                    .document(delegationId)
                    .getDocument()

                if let data = delegationDoc.data() {
                    delegation = parseDelegation(delegationDoc.documentID, data: data)
                }
            }

            logger.info("Delegation status: \(self.delegationActive)")
        } catch {
            logger.error("Failed to load delegation status: \(error.localizedDescription)")
        }
    }

    /// Start listener for delegation changes
    func startDelegationListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        delegationListener?.remove()

        delegationListener = db.collection("users")
            .document(userId)
            .collection("prediction_delegations")
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    logger.error("Delegation listener error: \(error.localizedDescription)")
                    return
                }

                Task { @MainActor in
                    if let doc = snapshot?.documents.first {
                        self.delegationActive = true
                        self.delegation = self.parseDelegation(doc.documentID, data: doc.data())
                    } else {
                        self.delegationActive = false
                        self.delegation = nil
                    }
                }
            }
    }

    func stopDelegationListener() {
        delegationListener?.remove()
        delegationListener = nil
    }

    /// Approve prediction copy trading delegation
    func approveDelegation(
        maxCopyAmountUsd: Double,
        copyPercentage: Double,
        minBetSizeUsd: Double,
        expirationDays: Int,
        privyAccessToken: String
    ) async throws {
        isDelegationLoading = true
        error = nil

        defer { isDelegationLoading = false }

        do {
            let result = try await functions.httpsCallable("approvePredictionDelegation").call([
                "maxCopyAmountUsd": maxCopyAmountUsd,
                "copyPercentage": copyPercentage,
                "minBetSizeUsd": minBetSizeUsd,
                "expirationDays": expirationDays,
                "privyAccessToken": privyAccessToken
            ])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool, success {
                delegationActive = true
                await loadDelegationStatus()
                logger.info("Delegation approved successfully")
            } else {
                throw PredictionCopyError.delegationFailed
            }
        } catch {
            logger.error("Failed to approve delegation: \(error.localizedDescription)")
            self.error = error.localizedDescription
            throw error
        }
    }

    /// Revoke prediction copy trading delegation
    func revokeDelegation() async throws {
        isDelegationLoading = true
        error = nil

        defer { isDelegationLoading = false }

        do {
            let result = try await functions.httpsCallable("revokePredictionDelegation").call([:])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool, success {
                delegationActive = false
                delegation = nil
                logger.info("Delegation revoked successfully")
            } else {
                throw PredictionCopyError.revokeFailed
            }
        } catch {
            logger.error("Failed to revoke delegation: \(error.localizedDescription)")
            self.error = error.localizedDescription
            throw error
        }
    }

    /// Execute a copy trade server-side (for users with delegation)
    func executeCopyServerSide(_ copy: PendingCopyTrade) async throws -> String {
        guard delegationActive else {
            throw PredictionCopyError.noDelegation
        }

        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let result = try await functions.httpsCallable("executePredictionCopyServer").call([
                "pendingCopyId": copy.id
            ])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool, success,
               let signature = data["signature"] as? String {
                pendingCopies.removeAll { $0.id == copy.id }
                logger.info("Copy executed server-side: \(signature)")
                return signature
            } else {
                let message = (result.data as? [String: Any])?["message"] as? String ?? "Unknown error"
                throw NSError(domain: "PredictionCopy", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            }
        } catch {
            logger.error("Server-side execution failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
            throw error
        }
    }

    private func parseDelegation(_ id: String, data: [String: Any]) -> PredictionDelegation {
        var expiresAt = Date()
        if let timestamp = data["expiresAt"] as? Timestamp {
            expiresAt = timestamp.dateValue()
        }

        return PredictionDelegation(
            id: id,
            status: data["status"] as? String ?? "unknown",
            maxCopyAmountUsd: data["maxCopyAmountUsd"] as? Double ?? 50,
            copyPercentage: data["copyPercentage"] as? Double ?? 10,
            minBetSizeUsd: data["minBetSizeUsd"] as? Double ?? 5,
            expiresAt: expiresAt,
            totalCopiesExecuted: data["totalCopiesExecuted"] as? Int ?? 0,
            totalVolumeUsd: data["totalVolumeUsd"] as? Double ?? 0
        )
    }

    // MARK: - Parsing

    private func parseTrackedPredictor(_ doc: DocumentSnapshot) -> TrackedPredictor? {
        let data = doc.data() ?? [:]

        guard let userId = data["userId"] as? String,
              let walletAddress = data["walletAddress"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        // Parse stats if available
        var stats: PredictorStats?
        if let statsData = data["stats"] as? [String: Any] {
            var lastBetAt: Date?
            if let timestamp = statsData["lastBetAt"] as? Timestamp {
                lastBetAt = timestamp.dateValue()
            }
            stats = PredictorStats(
                totalBets: statsData["totalBets"] as? Int ?? 0,
                winRate: statsData["winRate"] as? Double ?? 0,
                totalPnl: statsData["totalPnl"] as? Double ?? 0,
                avgBetSize: statsData["avgBetSize"] as? Double ?? 0,
                lastBetAt: lastBetAt
            )
        }

        return TrackedPredictor(
            id: doc.documentID,
            userId: userId,
            walletAddress: walletAddress,
            nickname: data["nickname"] as? String,
            createdAt: createdAt,
            stats: stats,
            autoCopyEnabled: data["autoCopyEnabled"] as? Bool ?? false,
            copyPercentage: data["copyPercentage"] as? Double ?? 5,
            maxCopyAmountUsd: data["maxCopyAmountUsd"] as? Double ?? 50,
            minBetSizeUsd: data["minBetSizeUsd"] as? Double ?? 5
        )
    }

    private func parsePendingCopyTrade(_ doc: DocumentSnapshot) -> PendingCopyTrade? {
        let data = doc.data() ?? [:]

        guard let userId = data["userId"] as? String,
              let userWalletAddress = data["userWalletAddress"] as? String,
              let betId = data["betId"] as? String,
              let trackedWallet = data["trackedWallet"] as? String,
              let marketAddress = data["marketAddress"] as? String,
              let direction = data["direction"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let expiresAt: Date
        if let timestamp = data["expiresAt"] as? Timestamp {
            expiresAt = timestamp.dateValue()
        } else {
            expiresAt = Date().addingTimeInterval(300) // Default 5 min
        }

        var executedAt: Date?
        if let timestamp = data["executedAt"] as? Timestamp {
            executedAt = timestamp.dateValue()
        }

        return PendingCopyTrade(
            id: doc.documentID,
            userId: userId,
            userWalletAddress: userWalletAddress,
            betId: betId,
            trackedWallet: trackedWallet,
            trackedWalletNickname: data["trackedWalletNickname"] as? String,
            marketAddress: marketAddress,
            marketTitle: data["marketTitle"] as? String,
            direction: direction,
            originalAmount: data["originalAmount"] as? Double ?? 0,
            originalPrice: data["originalPrice"] as? Double ?? 0,
            suggestedAmount: data["suggestedAmount"] as? Double ?? 0,
            status: data["status"] as? String ?? "pending",
            createdAt: createdAt,
            expiresAt: expiresAt,
            executedAt: executedAt,
            executedSignature: data["executedSignature"] as? String
        )
    }
}

// MARK: - Errors

enum PredictionCopyError: LocalizedError {
    case notAuthenticated
    case limitReached
    case alreadyTracking
    case addFailed
    case removeFailed
    case delegationFailed
    case revokeFailed
    case noDelegation

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Please sign in to track predictors"
        case .limitReached: return "You can only track up to 5 predictors"
        case .alreadyTracking: return "You're already tracking this wallet"
        case .addFailed: return "Failed to add predictor"
        case .removeFailed: return "Failed to remove predictor"
        case .delegationFailed: return "Failed to enable auto-copy"
        case .revokeFailed: return "Failed to disable auto-copy"
        case .noDelegation: return "Auto-copy not enabled"
        }
    }
}
