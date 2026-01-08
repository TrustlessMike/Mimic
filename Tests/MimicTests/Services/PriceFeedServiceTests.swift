import XCTest
@testable import Mimic

@MainActor
final class PriceFeedServiceTests: XCTestCase {

    var sut: PriceFeedService!

    override func setUp() async throws {
        try await super.setUp()
        sut = PriceFeedService.shared
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Price Caching Tests

    func testPricesAreInitiallyEmpty() {
        XCTAssertTrue(sut.prices.isEmpty, "Prices should be empty before first fetch")
    }

    func testChanges24hAreInitiallyEmpty() {
        XCTAssertTrue(sut.changes24h.isEmpty, "24h changes should be empty before first fetch")
    }

    // MARK: - Price Formatting Tests

    func testGetPriceReturnsNilForUnknownSymbol() {
        let price = sut.getPrice(for: "UNKNOWN_TOKEN_XYZ")
        XCTAssertNil(price, "Unknown token should return nil price")
    }

    func testGetChange24hReturnsNilForUnknownSymbol() {
        let change = sut.getChange24h(for: "UNKNOWN_TOKEN_XYZ")
        XCTAssertNil(change, "Unknown token should return nil 24h change")
    }

    // MARK: - Integration Tests (require network)

    func testRefreshPricesFetchesData() async throws {
        // This test requires network access and configured API keys
        // Skip in CI environments without proper setup
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping network test in CI environment")
        }

        await sut.refreshPrices()

        // After refresh, we should have some prices (at minimum SOL)
        XCTAssertFalse(sut.prices.isEmpty, "Prices should not be empty after refresh")
    }
}
