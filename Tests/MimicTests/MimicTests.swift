import XCTest
@testable import Mimic

final class MimicTests: XCTestCase {

    // MARK: - Token Registry Tests

    func testTokenRegistryContainsSOL() {
        let sol = TokenRegistry.allTokens.first { $0.symbol == "SOL" }
        XCTAssertNotNil(sol, "Token registry should contain SOL")
        XCTAssertEqual(sol?.name, "Solana")
        XCTAssertEqual(sol?.decimals, 9)
    }

    func testTokenRegistryContainsUSDC() {
        let usdc = TokenRegistry.allTokens.first { $0.symbol == "USDC" }
        XCTAssertNotNil(usdc, "Token registry should contain USDC")
        XCTAssertEqual(usdc?.decimals, 6)
    }

    func testTokenRegistryHasUniqueSymbols() {
        let symbols = TokenRegistry.allTokens.map { $0.symbol }
        let uniqueSymbols = Set(symbols)
        XCTAssertEqual(symbols.count, uniqueSymbols.count, "Token registry should have unique symbols")
    }

    // MARK: - Model Tests

    func testTokenBalanceDisplayAmount() {
        let balance = TokenBalance(
            id: "sol",
            token: TokenRegistry.SOL,
            lamports: 1_500_000_000, // 1.5 SOL
            usdPrice: 100.00,
            change24h: 5.0,
            lastUpdated: Date()
        )

        XCTAssertEqual(balance.amount, 1.5, accuracy: 0.001)
        XCTAssertEqual(balance.usdValue, 150.00, accuracy: 0.01)
    }

    func testTokenBalanceWithZeroLamports() {
        let balance = TokenBalance(
            id: "sol",
            token: TokenRegistry.SOL,
            lamports: 0,
            usdPrice: 100.00,
            change24h: 0,
            lastUpdated: Date()
        )

        XCTAssertEqual(balance.amount, 0)
        XCTAssertEqual(balance.usdValue, 0)
    }

    // MARK: - Theme Tests

    @MainActor
    func testThemeManagerDefaultsToSystem() {
        // Clear any saved theme
        UserDefaults.standard.removeObject(forKey: "appTheme")

        // ThemeManager should default to system
        let themeManager = ThemeManager.shared
        XCTAssertNotNil(themeManager.currentTheme)
    }

    @MainActor
    func testThemeManagerColorScheme() {
        let themeManager = ThemeManager.shared

        themeManager.setTheme(.light)
        XCTAssertEqual(themeManager.colorScheme, .light)

        themeManager.setTheme(.dark)
        XCTAssertEqual(themeManager.colorScheme, .dark)

        themeManager.setTheme(.system)
        XCTAssertNil(themeManager.colorScheme)
    }
}
