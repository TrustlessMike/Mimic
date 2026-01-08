import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog

/// Service for managing user's prediction market positions
@MainActor
class PositionsService: ObservableObject {
    static let shared = PositionsService()

    private let logger = Logger(subsystem: "com.mimic.app", category: "PositionsService")
    private let db = Firestore.firestore()

    @Published var positions: [UserPosition] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Computed stats
    var totalPnl: Double {
        positions.reduce(0) { $0 + $1.unrealizedPnl }
    }

    var openCount: Int {
        positions.filter { $0.status == .open }.count
    }

    var wonCount: Int {
        positions.filter { $0.status == .won || $0.status == .claimed }.count
    }

    var lostCount: Int {
        positions.filter { $0.status == .lost }.count
    }

    var winRate: Int {
        let resolved = wonCount + lostCount
        guard resolved > 0 else { return 0 }
        return Int((Double(wonCount) / Double(resolved)) * 100)
    }

    var totalInvested: Double {
        positions.filter { $0.status == .open }.reduce(0) { $0 + $1.amount }
    }

    var totalCurrentValue: Double {
        positions.filter { $0.status == .open }.reduce(0) { $0 + ($1.currentValue ?? $1.amount) }
    }

    private var positionsListener: ListenerRegistration?

    private init() {}

    deinit {
        positionsListener?.remove()
    }

    // MARK: - Load Positions

    /// Load all positions for the current user
    func loadPositions() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            logger.warning("No authenticated user")
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("user_positions")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            positions = snapshot.documents.compactMap { doc in
                parsePosition(doc)
            }

            logger.info("Loaded \(self.positions.count) positions")
        } catch {
            logger.error("Failed to load positions: \(error.localizedDescription)")
            errorMessage = "Failed to load positions"
        }

        isLoading = false
    }

    // MARK: - Real-time Listener

    /// Start listening for position updates
    func startPositionsListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        positionsListener?.remove()

        positionsListener = db.collection("user_positions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.logger.error("Positions listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    self.positions = documents.compactMap { doc in
                        self.parsePosition(doc)
                    }
                }
            }
    }

    /// Stop listening for updates
    func stopPositionsListener() {
        positionsListener?.remove()
        positionsListener = nil
    }

    // MARK: - Create Position (from copy trade)

    /// Create a new position when copying a bet
    func createPosition(
        marketAddress: String,
        marketTitle: String?,
        direction: String,
        amount: Double,
        shares: Double,
        avgPrice: Double,
        copiedFromWallet: String? = nil,
        copiedFromBetId: String? = nil
    ) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw PositionsError.notAuthenticated
        }

        let positionData: [String: Any] = [
            "userId": userId,
            "marketAddress": marketAddress,
            "marketTitle": marketTitle ?? "",
            "direction": direction,
            "amount": amount,
            "shares": shares,
            "avgPrice": avgPrice,
            "status": "open",
            "unrealizedPnl": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "copiedFromWallet": copiedFromWallet ?? "",
            "copiedFromBetId": copiedFromBetId ?? ""
        ]

        let docRef = try await db.collection("user_positions").addDocument(data: positionData)
        logger.info("Created position: \(docRef.documentID)")

        return docRef.documentID
    }

    // MARK: - Update Position

    /// Update position with current market price and P&L
    func updatePositionPrice(positionId: String, currentPrice: Double) async throws {
        guard let position = positions.first(where: { $0.id == positionId }) else {
            throw PositionsError.notFound
        }

        // Calculate current value and P&L
        let currentValue = position.shares * currentPrice
        let unrealizedPnl = currentValue - position.amount

        try await db.collection("user_positions").document(positionId).updateData([
            "currentPrice": currentPrice,
            "currentValue": currentValue,
            "unrealizedPnl": unrealizedPnl
        ])
    }

    /// Mark position as resolved
    func resolvePosition(positionId: String, won: Bool, finalPnl: Double) async throws {
        let status = won ? "won" : "lost"

        try await db.collection("user_positions").document(positionId).updateData([
            "status": status,
            "unrealizedPnl": finalPnl,
            "resolvedAt": FieldValue.serverTimestamp()
        ])

        logger.info("Position \(positionId) resolved: \(status)")
    }

    // MARK: - Parsing

    private func parsePosition(_ doc: DocumentSnapshot) -> UserPosition? {
        let data = doc.data() ?? [:]

        guard let userId = data["userId"] as? String,
              let marketAddress = data["marketAddress"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        var resolvedAt: Date?
        if let timestamp = data["resolvedAt"] as? Timestamp {
            resolvedAt = timestamp.dateValue()
        }

        let status: UserPosition.PositionStatus
        if let statusStr = data["status"] as? String {
            status = UserPosition.PositionStatus(rawValue: statusStr) ?? .open
        } else {
            status = .open
        }

        return UserPosition(
            id: doc.documentID,
            userId: userId,
            marketAddress: marketAddress,
            marketTitle: data["marketTitle"] as? String,
            direction: data["direction"] as? String ?? "YES",
            amount: data["amount"] as? Double ?? 0,
            shares: data["shares"] as? Double ?? 0,
            avgPrice: data["avgPrice"] as? Double ?? 0,
            status: status,
            unrealizedPnl: data["unrealizedPnl"] as? Double ?? 0,
            currentPrice: data["currentPrice"] as? Double,
            currentValue: data["currentValue"] as? Double,
            createdAt: createdAt,
            resolvedAt: resolvedAt,
            copiedFromWallet: data["copiedFromWallet"] as? String,
            copiedFromBetId: data["copiedFromBetId"] as? String
        )
    }
}

// MARK: - Errors

enum PositionsError: LocalizedError {
    case notAuthenticated
    case notFound
    case createFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated"
        case .notFound: return "Position not found"
        case .createFailed: return "Failed to create position"
        }
    }
}
