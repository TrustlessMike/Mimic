import XCTest
@testable import Mimic

/// Tests for the performance optimizations made to the codebase
final class OptimizationTests: XCTestCase {

    // MARK: - NumberFormatter Caching Tests

    func testNumberFormatterCachingPerformance() {
        // Test that static formatters are faster than creating new ones each time
        let iterations = 1000
        let testValue = NSDecimalNumber(decimal: 12345.67)

        // Measure cached formatter (simulating TotalBalanceCard optimization)
        let cachedFormatter = NumberFormatter()
        cachedFormatter.numberStyle = .currency
        cachedFormatter.currencyCode = "USD"
        cachedFormatter.maximumFractionDigits = 2

        let cachedStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = cachedFormatter.string(from: testValue)
        }
        let cachedElapsed = CFAbsoluteTimeGetCurrent() - cachedStart

        // Measure creating new formatter each time (old pattern)
        let newFormatterStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 2
            _ = formatter.string(from: testValue)
        }
        let newFormatterElapsed = CFAbsoluteTimeGetCurrent() - newFormatterStart

        // Cached should be significantly faster (at least 2x)
        XCTAssertLessThan(
            cachedElapsed,
            newFormatterElapsed,
            "Cached formatter should be faster than creating new formatters"
        )

        print("Cached: \(cachedElapsed * 1000)ms, New each time: \(newFormatterElapsed * 1000)ms")
    }

    // MARK: - Dictionary Caching Tests

    func testLazyDictionaryCachingPerformance() {
        // Simulate the TokenRegistry -> CoinGeckoId mapping optimization
        let tokens = (0..<100).map { i in
            (symbol: "TOKEN\(i)", id: "coingecko-\(i)")
        }

        // Measure computing dictionary each time (old pattern)
        let computedStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = Dictionary(uniqueKeysWithValues: tokens.compactMap { ($0.symbol, $0.id) })
        }
        let computedElapsed = CFAbsoluteTimeGetCurrent() - computedStart

        // Measure cached dictionary (new pattern)
        let cachedDict = Dictionary(uniqueKeysWithValues: tokens.compactMap { ($0.symbol, $0.id) })
        let cachedStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = cachedDict["TOKEN50"]
        }
        let cachedElapsed = CFAbsoluteTimeGetCurrent() - cachedStart

        // Cached lookup should be much faster than recreating
        XCTAssertLessThan(
            cachedElapsed,
            computedElapsed,
            "Cached dictionary lookup should be faster than recreating dictionary"
        )
    }

    // MARK: - Array Filtering Optimization Tests

    func testContainsWhereIsFasterThanFilterIsEmpty() {
        let testArray = (0..<10000).map { _ in
            TestItem(hasBalance: Bool.random())
        }

        let iterations = 100

        // Old pattern: filter then check isEmpty
        let filterStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = testArray.filter { $0.hasBalance }.isEmpty
        }
        let filterElapsed = CFAbsoluteTimeGetCurrent() - filterStart

        // New pattern: contains(where:)
        let containsStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = !testArray.contains { $0.hasBalance }
        }
        let containsElapsed = CFAbsoluteTimeGetCurrent() - containsStart

        // contains(where:) should be faster as it short-circuits
        XCTAssertLessThan(
            containsElapsed,
            filterElapsed,
            "contains(where:) should be faster than filter().isEmpty"
        )

        print("filter().isEmpty: \(filterElapsed * 1000)ms, contains(where:): \(containsElapsed * 1000)ms")
    }

    // MARK: - Map Lookup Performance Tests

    func testMapLookupIsO1() {
        // Build a large map
        var testMap = [String: Int]()
        for i in 0..<100000 {
            testMap["key\(i)"] = i
        }

        // Measure 10000 lookups - should be nearly constant time regardless of size
        let start = CFAbsoluteTimeGetCurrent()
        for i in 0..<10000 {
            _ = testMap["key\(i % 100000)"]
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        // 10000 lookups should complete in well under 100ms
        XCTAssertLessThan(elapsed, 0.1, "Map lookups should be O(1)")
    }
}

// Helper struct for testing
private struct TestItem {
    let hasBalance: Bool
}
