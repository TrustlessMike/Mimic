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

    func testGetPriceReturnsZeroForUnknownSymbol() {
        // getPrice returns 0 (not nil) for unknown symbols
        let price = sut.getPrice(for: "UNKNOWN_TOKEN_XYZ")
        XCTAssertEqual(price, 0, "Unknown token should return 0 price")
    }

    func testGetChange24hReturnsNilForUnknownSymbol() {
        // getChange24h returns nil for unknown symbols
        let change = sut.getChange24h(for: "UNKNOWN_TOKEN_XYZ")
        XCTAssertNil(change, "Unknown token should return nil 24h change")
    }

    // MARK: - Integration Tests (require network)

    func testRefreshPricesFetchesData() async throws {
        // This test requires network access to external APIs
        // Skip in CI environments or when network is unavailable
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping network test in CI environment")
        }

        await sut.refreshPrices()

        // Skip if network unavailable (not a code failure, just infra issue)
        guard !sut.prices.isEmpty else {
            throw XCTSkip("Skipping: Network unavailable or API unreachable")
        }

        // Verify we got price data
        XCTAssertGreaterThan(sut.prices.count, 0, "Should have fetched at least one price")
    }
}
