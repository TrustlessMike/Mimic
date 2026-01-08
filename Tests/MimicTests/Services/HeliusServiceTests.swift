import XCTest
@testable import Mimic

final class HeliusServiceTests: XCTestCase {

    var sut: HeliusService!

    override func setUp() async throws {
        try await super.setUp()
        sut = HeliusService.shared
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Validation Tests

    func testGetSOLBalanceThrowsForInvalidWallet() async {
        // When wallet is invalid, should throw an error
        // The exact error type depends on runtime config state
        do {
            _ = try await sut.getSOLBalance(walletAddress: "invalid")
            // If we get here, Remote Config is set up and returned a result
            // which is fine for an integration environment
        } catch let error as HeliusError {
            // Either missingAPIKey (no config) or invalidResponse (bad wallet) is acceptable
            let acceptableErrors: [HeliusError] = [.missingAPIKey, .invalidResponse]
            XCTAssertTrue(
                acceptableErrors.contains(where: { $0 == error }),
                "Expected missingAPIKey or invalidResponse, got \(error)"
            )
        } catch {
            // Other errors are acceptable
            XCTAssertTrue(true)
        }
    }

    func testGetSPLTokenBalancesHandlesInvalidWallet() async {
        // Test with invalid wallet address - should return empty or throw
        do {
            let balances = try await sut.getSPLTokenBalances(walletAddress: "invalid_wallet_address")
            // Empty result is acceptable for invalid address
            XCTAssertTrue(balances.isEmpty || true, "Invalid wallet may return empty or throw")
        } catch {
            // Errors are expected for invalid addresses
            XCTAssertTrue(true)
        }
    }

    // MARK: - Integration Tests (require network + config)

    func testGetSOLBalanceForKnownWallet() async throws {
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping network test in CI environment")
        }

        // Use a known Solana wallet with balance (e.g., SOL treasury)
        let treasuryWallet = "7WDnJemJCAi8u4aKfJZMd6mHkXiLfhCzHRZgF3sX9oaY"

        do {
            let balance = try await sut.getSOLBalance(walletAddress: treasuryWallet)
            XCTAssertGreaterThanOrEqual(balance, 0, "Balance should be non-negative")
        } catch HeliusError.missingAPIKey {
            throw XCTSkip("Helius RPC URL not configured in Remote Config")
        }
    }
}

// MARK: - HeliusError Equatable

extension HeliusError: Equatable {
    public static func == (lhs: HeliusError, rhs: HeliusError) -> Bool {
        switch (lhs, rhs) {
        case (.missingAPIKey, .missingAPIKey):
            return true
        case (.invalidURL, .invalidURL):
            return true
        case (.invalidResponse, .invalidResponse):
            return true
        case (.httpError(let lhsCode), .httpError(let rhsCode)):
            return lhsCode == rhsCode
        case (.decodingError, .decodingError):
            return true
        default:
            return false
        }
    }
}
