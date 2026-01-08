import Foundation
import FirebaseFunctions
import FirebaseAuth
import OSLog

private let logger = Logger(subsystem: "com.mimic.app", category: "FirebaseCallable")

/// Wrapper around Firebase Callable Functions with automatic idToken injection and retry logic
@MainActor
class FirebaseCallableClient {
    static let shared = FirebaseCallableClient()

    private let functions: Functions
    private var isCallInProgress = false

    private init() {
        functions = Functions.functions()
    }

    /// Calls a Firebase Callable Function with automatic idToken injection and retry/backoff on transient errors
    func call(
        _ name: String,
        data: [String: Any],
        timeout: TimeInterval = 45,
        retries: Int = 3
    ) async throws -> HTTPSCallableResult {
        // Wait if another call is in progress to avoid GTMSessionFetcher conflicts
        while isCallInProgress {
            logger.debug("Waiting for previous call to complete...")
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        isCallInProgress = true
        defer { isCallInProgress = false }

        var attempt = 0
        var lastError: Error?

        while attempt <= retries {
            do {
                // Ensure we have a valid auth token before each attempt
                if let user = Auth.auth().currentUser {
                    _ = try await user.getIDToken()
                }

                let callable = functions.httpsCallable(name)
                callable.timeoutInterval = timeout
                return try await callable.call(data)
            } catch let error as NSError {
                lastError = error
                logger.error("Firebase call '\(name)' failed (attempt \(attempt + 1)): \(error.localizedDescription)")

                // Check if error is retryable
                if isRetryableError(error) && attempt < retries {
                    // Force token refresh on auth errors
                    if error.code == FunctionsErrorCode.unauthenticated.rawValue {
                        logger.info("Forcing token refresh after unauthenticated error")
                        if let user = Auth.auth().currentUser {
                            _ = try? await user.getIDTokenResult(forcingRefresh: true)
                        }
                    }

                    let backoffDelay = calculateBackoff(attempt: attempt)
                    logger.debug("Retrying in \(backoffDelay)s...")
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    attempt += 1
                    continue
                } else {
                    throw error
                }
            }
        }

        throw lastError ?? FirebaseCallableError.unknownError
    }

    private func isRetryableError(_ error: NSError) -> Bool {
        // Retry on network errors, timeouts, server errors, and auth errors
        let retryableCodes = [
            FunctionsErrorCode.unavailable.rawValue,
            FunctionsErrorCode.deadlineExceeded.rawValue,
            FunctionsErrorCode.internal.rawValue,
            FunctionsErrorCode.unauthenticated.rawValue  // Retry auth errors with token refresh
        ]

        return retryableCodes.contains(error.code)
    }

    private func calculateBackoff(attempt: Int) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s, 8s, etc.
        return min(pow(2.0, Double(attempt)), 10.0)
    }
}

enum FirebaseCallableError: LocalizedError {
    case unknownError

    var errorDescription: String? {
        switch self {
        case .unknownError:
            return "An unknown error occurred while calling Firebase function"
        }
    }
}
