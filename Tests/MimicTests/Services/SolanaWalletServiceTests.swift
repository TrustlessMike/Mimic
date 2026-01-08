import XCTest
@testable import Mimic

@MainActor
final class SolanaWalletServiceTests: XCTestCase {

    var sut: SolanaWalletService!

    override func setUp() async throws {
        try await super.setUp()
        sut = SolanaWalletService.shared
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testBalancesAreInitiallyEmpty() {
        XCTAssertTrue(sut.balances.isEmpty, "Balances should be empty initially")
    }

    func testIsLoadingDefaultsToFalse() {
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
    }

    func testErrorIsInitiallyNil() {
        XCTAssertNil(sut.error, "Error should be nil initially")
    }

    // MARK: - Filtered Balances Optimization Tests

    func testFilteredBalancesReturnsOnlyNonZeroBalances() {
        // This tests the filteredBalances computed property optimization
        // The property should filter out zero balances efficiently
        let filteredBalances = sut.filteredBalances

        // All filtered balances should have hasBalance == true
        for balance in filteredBalances {
            XCTAssertTrue(balance.hasBalance, "Filtered balances should only contain non-zero balances")
        }
    }

    func testFilteredBalancesIsConsistentWithManualFilter() {
        // Verify the optimization returns same results as manual filter
        let manualFiltered = sut.balances.filter { $0.hasBalance }
        let optimizedFiltered = sut.filteredBalances

        XCTAssertEqual(
            manualFiltered.count,
            optimizedFiltered.count,
            "Optimized filter should return same count as manual filter"
        )
    }

    // MARK: - Total Value Tests

    func testTotalUSDValueIsZeroWhenEmpty() {
        XCTAssertEqual(sut.totalUSDValue, 0, "Total USD should be 0 when no balances")
    }

    // MARK: - Last Updated Tests

    func testLastUpdatedIsNilInitially() {
        XCTAssertNil(sut.lastUpdated, "Last updated should be nil initially")
    }
}
