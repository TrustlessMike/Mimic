import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Wickett", category: "SwapViewModel")

@MainActor
class SwapViewModel: ObservableObject {
    // MARK: - Published State
    @Published var fromToken: SolanaToken = TokenRegistry.USDC
    @Published var toToken: SolanaToken = TokenRegistry.SOL
    @Published var fromAmount: String = ""
    @Published var isLoading = false
    @Published var transactionState: TransactionState = .idle
    @Published var errorMessage: String?
    @Published var transactionSignature: String?
    @Published var currentQuote: JupiterQuote?
    @Published var isRefreshingQuote = false
    @Published var slippageBps: Int = 50 // Default 0.5%

    // MARK: - Dependencies
    private let firebaseClient = FirebaseCallableClient.shared
    let walletService = SolanaWalletService.shared
    private let signingService = SolanaSigningService.shared
    private let privyService = HybridPrivyService.shared

    // MARK: - Private State
    nonisolated(unsafe) private var quoteRefreshTimer: Timer?
    private var quoteCancellable: AnyCancellable?
    private var amountDebounceTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Minimum USD value for swaps (Jupiter can't route tiny amounts)
    private static let minimumSwapUSD: Decimal = 0.01

    /// Parsed from amount as lamports
    var fromAmountLamports: UInt64? {
        guard let amount = Decimal(string: fromAmount), amount > 0 else {
            return nil
        }
        return fromToken.toLamports(amount)
    }

    /// USD value of the from amount
    var fromAmountUSD: Decimal? {
        guard let amount = Decimal(string: fromAmount),
              amount > 0,
              let balance = walletService.balances.first(where: { $0.token.symbol == fromToken.symbol }),
              balance.usdPrice > 0 else {
            return nil
        }
        return amount * balance.usdPrice
    }

    /// Whether the swap amount meets minimum USD threshold
    var meetsMinimumSwapValue: Bool {
        guard let usdValue = fromAmountUSD else { return false }
        return usdValue >= Self.minimumSwapUSD
    }

    /// Current from token balance
    var fromTokenBalance: Decimal? {
        guard let balance = walletService.balances.first(where: { $0.token.symbol == fromToken.symbol }) else {
            return nil
        }
        return fromToken.fromLamports(balance.lamports)
    }

    /// Check if user has sufficient balance
    var hasSufficientBalance: Bool {
        guard let amount = Decimal(string: fromAmount),
              amount > 0,
              let balance = fromTokenBalance else {
            return false
        }
        return balance >= amount
    }

    /// Whether swap button should be enabled
    var canSwap: Bool {
        guard !fromAmount.isEmpty,
              let amount = Decimal(string: fromAmount),
              amount > 0,
              fromToken.symbol != toToken.symbol,
              hasSufficientBalance,
              currentQuote != nil,
              transactionState == .idle else {
            return false
        }
        return true
    }

    /// Exchange rate display text
    var exchangeRateText: String? {
        guard let quote = currentQuote,
              let rate = quote.exchangeRate else {
            return nil
        }
        return "1 \(fromToken.symbol) ≈ \(formatDecimal(rate)) \(toToken.symbol)"
    }

    /// Estimated output amount
    var estimatedOutputAmount: String? {
        guard let quote = currentQuote else {
            return nil
        }
        return quote.formattedOutputAmount(for: toToken)
    }

    /// USD value of output amount
    var outputAmountUSD: String? {
        guard let quote = currentQuote,
              let outAmount = UInt64(quote.outAmount),
              let balance = walletService.balances.first(where: { $0.token.symbol == toToken.symbol }),
              balance.usdPrice > 0 else {
            return nil
        }
        let tokenAmount = toToken.fromLamports(outAmount)
        let usdValue = tokenAmount * balance.usdPrice
        return String(format: "$%.2f", NSDecimalNumber(decimal: usdValue).doubleValue)
    }

    /// Minimum output after slippage
    var minimumOutputAmount: String? {
        guard let quote = currentQuote,
              let minAmount = quote.minimumOutputAmount(for: toToken) else {
            return nil
        }
        return formatDecimal(minAmount)
    }

    /// Price impact percentage display
    var priceImpactText: String? {
        guard let quote = currentQuote,
              let impact = quote.priceImpact else {
            return nil
        }
        let percentage = impact * 100
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }

    /// Price impact color (green/yellow/red based on severity)
    var priceImpactColor: Color {
        guard let quote = currentQuote,
              let impact = quote.priceImpact else {
            return .secondary
        }
        let percentage = abs(NSDecimalNumber(decimal: impact * 100).doubleValue)

        if percentage < 1 {
            return .green
        } else if percentage < 5 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Initialization

    init() {
        // Initialize with default tokens (will be updated in initializeWithUserBalances)
        self.fromToken = TokenRegistry.SOL
        self.toToken = TokenRegistry.USDC
    }

    /// Initialize tokens based on user's actual balances (call from onAppear)
    func initializeWithUserBalances() {
        // Start with first token user owns (or keep default SOL)
        if let firstBalance = walletService.balances.first(where: { $0.hasBalance }) {
            fromToken = firstBalance.token
            // Set toToken to a different token (prefer USDC/USDT, fallback to SOL)
            if fromToken.symbol == "SOL" {
                toToken = TokenRegistry.USDC
            } else {
                toToken = TokenRegistry.SOL
            }
            logger.info("✅ SwapViewModel initialized with user balances: \(self.fromToken.symbol) → \(self.toToken.symbol)")
        } else {
            logger.info("⚠️ No balances found, using defaults: \(self.fromToken.symbol) → \(self.toToken.symbol)")
        }

        // Fetch initial quote if amount is set
        if !fromAmount.isEmpty {
            Task {
                await fetchQuote()
            }
        }
    }

    // MARK: - Quote Management

    // Wrapped SOL mint address used by Jupiter for native SOL swaps
    private static let wrappedSOLMint = "So11111111111111111111111111111111111111112"

    /// Fetch quote from Jupiter via Cloud Function
    /// Also stores the unsigned transaction for later execution
    private var pendingSwapTransaction: String?
    private var pendingRequestId: String?

    func fetchQuote() async {
        guard let amountLamports = fromAmountLamports,
              amountLamports > 0,
              fromToken.symbol != toToken.symbol else {
            currentQuote = nil
            pendingSwapTransaction = nil
            pendingRequestId = nil
            return
        }

        // Check minimum USD value - Jupiter can't route dust amounts
        guard meetsMinimumSwapValue else {
            currentQuote = nil
            pendingSwapTransaction = nil
            pendingRequestId = nil
            errorMessage = "Amount too small to swap (min $0.01)"
            logger.info("⚠️ Swap amount below minimum USD threshold")
            return
        }

        // Use wrapped SOL address for native SOL, otherwise use token's mint
        let fromMint = fromToken.mint ?? Self.wrappedSOLMint
        let toMint = toToken.mint ?? Self.wrappedSOLMint

        isRefreshingQuote = true
        errorMessage = nil

        do {
            // Get user wallet address from Privy
            guard let walletAddress = try? await getWalletAddress() else {
                throw SwapError.invalidAmount
            }

            let data: [String: Any] = [
                "inputMint": fromMint,
                "outputMint": toMint,
                "amount": Int(amountLamports),
                "slippageBps": slippageBps,
                "userWalletAddress": walletAddress
            ]

            logger.info("📊 Fetching quote: \(fromMint) → \(toMint), amount: \(amountLamports)")

            let result = try await firebaseClient.call("getJupiterSwapTransaction", data: data)

            // Parse response
            guard let resultData = result.data as? [String: Any] else {
                logger.error("❌ Invalid response format from getJupiterSwapTransaction")
                throw SwapError.buildFailed("Invalid response format")
            }

            // Check for error in response
            if let errorMsg = resultData["error"] as? String {
                logger.error("❌ Backend error: \(errorMsg)")
                throw SwapError.buildFailed(errorMsg)
            }

            guard let success = resultData["success"] as? Bool, success,
                  let responseData = resultData["data"] as? [String: Any] else {
                let code = resultData["code"] as? String ?? "UNKNOWN"
                logger.error("❌ Quote failed with code: \(code)")
                throw SwapError.buildFailed("Quote failed: \(code)")
            }

            // Store the unsigned transaction and requestId for later execution
            guard let transaction = responseData["transaction"] as? String else {
                logger.error("❌ No transaction in response")
                throw SwapError.buildFailed("No transaction returned")
            }
            pendingSwapTransaction = transaction
            pendingRequestId = responseData["requestId"] as? String

            // Create quote from response data
            let quote = JupiterQuote(
                inputMint: responseData["inputMint"] as? String ?? fromMint,
                outputMint: responseData["outputMint"] as? String ?? toMint,
                inAmount: responseData["inAmount"] as? String ?? "",
                outAmount: responseData["outAmount"] as? String ?? "",
                priceImpactPct: responseData["priceImpactPct"] as? String ?? "0",
                slippageBps: responseData["slippageBps"] as? Int ?? slippageBps
            )

            currentQuote = quote
            logger.info("✅ Quote fetched: \(quote.inAmount) → \(quote.outAmount)")
        } catch {
            logger.error("❌ Failed to fetch quote: \(error)")
            currentQuote = nil
            pendingSwapTransaction = nil
            pendingRequestId = nil

            // Show user-friendly error message
            if let swapError = error as? SwapError {
                switch swapError {
                case .buildFailed(let msg):
                    if msg.contains("No route found") || msg.contains("Could not find any route") || msg.contains("Failed to get quotes") {
                        errorMessage = "No swap route available for \(fromToken.symbol) → \(toToken.symbol). Try a different token pair."
                    } else {
                        errorMessage = msg
                    }
                default:
                    errorMessage = swapError.localizedDescription
                }
            } else {
                errorMessage = "Failed to get quote: \(error.localizedDescription)"
            }
        }

        isRefreshingQuote = false
    }

    /// Start auto-refreshing quotes every 15 seconds
    func startQuoteRefresh() {
        stopQuoteRefresh()

        quoteRefreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchQuote()
            }
        }
    }

    /// Stop auto-refreshing quotes
    nonisolated func stopQuoteRefresh() {
        quoteRefreshTimer?.invalidate()
        quoteRefreshTimer = nil
    }

    // MARK: - Token Selection

    /// Swap from and to tokens
    func swapTokens() {
        let temp = fromToken
        fromToken = toToken
        toToken = temp

        // Keep amount - will auto-refresh quote
        Task {
            await fetchQuote()
        }
    }

    /// Update from token and refresh quote
    func updateFromToken(_ token: SolanaToken) {
        guard fromToken.symbol != token.symbol else { return }
        fromToken = token

        // Ensure from and to are different
        if fromToken.symbol == toToken.symbol {
            // Swap to a different token
            toToken = fromToken.symbol == "SOL" ? TokenRegistry.USDC : TokenRegistry.SOL
        }

        Task {
            await fetchQuote()
        }
    }

    /// Update to token and refresh quote
    func updateToToken(_ token: SolanaToken) {
        guard toToken.symbol != token.symbol else { return }
        toToken = token

        // Ensure from and to are different
        if fromToken.symbol == toToken.symbol {
            // Swap to a different token
            fromToken = toToken.symbol == "USDC" ? TokenRegistry.SOL : TokenRegistry.USDC
        }

        Task {
            await fetchQuote()
        }
    }

    // MARK: - Amount Management

    /// Update amount and refresh quote (with debouncing)
    func updateAmount(_ amount: String) {
        // Cancel any pending debounce task
        amountDebounceTask?.cancel()

        // Don't set fromAmount here - it's already bound to the TextField
        // Just trigger the quote fetch with debouncing

        amountDebounceTask = Task {
            // Debounce quote fetching - wait 500ms
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Check if task was cancelled during sleep
            guard !Task.isCancelled else { return }

            await fetchQuote()
        }
    }

    /// Set amount to max balance
    func setMaxAmount() {
        guard let balance = fromTokenBalance else { return }

        // For SOL, leave a small amount for rent/fees (0.001 SOL)
        let maxAmount = if fromToken.symbol == "SOL" {
            max(balance - 0.001, 0)
        } else {
            balance
        }

        fromAmount = formatDecimal(maxAmount)

        Task {
            await fetchQuote()
        }
    }

    // MARK: - Slippage Management

    /// Update slippage tolerance
    func updateSlippage(_ bps: Int) {
        slippageBps = bps

        Task {
            await fetchQuote()
        }
    }

    // MARK: - Swap Execution

    /// Execute swap transaction (2-step flow: sign with Privy, execute via Jupiter Ultra API)
    func executeSwap() async {
        guard canSwap,
              let unsignedTransaction = pendingSwapTransaction,
              let requestId = pendingRequestId else {
            errorMessage = "No swap ready. Please refresh the quote."
            return
        }

        isLoading = true
        errorMessage = nil
        transactionSignature = nil

        do {
            // Step 1: Sign transaction with Privy
            logger.info("✍️ Step 1: Signing swap...")
            transactionState = .signing

            let signedTx = try await signingService.signUnsignedTransaction(unsignedTransaction)
            logger.info("✅ Swap signed")

            // Step 2: Execute via Jupiter Ultra API
            let signature = try await executeJupiterSwap(signedTransaction: signedTx, requestId: requestId)

            transactionSignature = signature
            transactionState = .completed

            // Reset form
            fromAmount = ""
            currentQuote = nil
            pendingSwapTransaction = nil
            pendingRequestId = nil

            // Refresh wallet balances (force to bypass cache after swap)
            if let wallet = try? await getWalletAddress() {
                await walletService.refreshBalances(walletAddress: wallet, force: true)
            }

        } catch {
            logger.error("❌ Swap failed: \(error)")
            errorMessage = error.localizedDescription
            transactionState = .failed
        }

        isLoading = false
    }

    /// Execute signed swap via Jupiter Ultra API
    private func executeJupiterSwap(signedTransaction: String, requestId: String) async throws -> String {
        logger.info("🚀 Step 2: Executing swap...")
        transactionState = .broadcasting

        let data: [String: Any] = [
            "signedTransaction": signedTransaction,
            "requestId": requestId
        ]

        let result = try await firebaseClient.call("executeJupiterSwap", data: data)

        // Parse response
        guard let resultData = result.data as? [String: Any],
              let success = resultData["success"] as? Bool,
              success else {
            let error = (result.data as? [String: Any])?["error"] as? String ?? "Swap execution failed"
            throw SwapError.broadcastFailed(error)
        }

        guard let responseData = resultData["data"] as? [String: Any],
              let signature = responseData["signature"] as? String else {
            throw SwapError.broadcastFailed("Invalid response - missing signature")
        }

        logger.info("✅ Swap executed: \(signature)")
        return signature
    }

    // MARK: - Private Transaction Methods

    private func broadcastTransaction(_ signedTransaction: String) async throws -> String {
        logger.info("📡 Step 3: Broadcasting signed transaction...")
        transactionState = .broadcasting

        let data: [String: Any] = [
            "signedTransaction": signedTransaction,
            "transactionType": "jupiter_swap"
        ]

        let result = try await firebaseClient.call("broadcastSignedTransaction", data: data)

        // Parse response
        guard let resultData = result.data as? [String: Any],
              let success = resultData["success"] as? Bool,
              success else {
            let error = (result.data as? [String: Any])?["error"] as? String ?? "Broadcast failed"
            throw SwapError.broadcastFailed(error)
        }

        guard let responseData = resultData["data"] as? [String: Any],
              let signature = responseData["transactionHash"] as? String else {
            throw SwapError.broadcastFailed("Invalid response format - missing transaction hash")
        }

        logger.info("✅ Transaction broadcasted: \(signature)")
        return signature
    }

    // MARK: - Helpers

    private func getWalletAddress() async throws -> String {
        // Get wallet address from HybridPrivyService
        guard let address = privyService.walletAddress else {
            throw SwapError.invalidAmount
        }
        return address
    }

    private func formatDecimal(_ decimal: Decimal) -> String {
        let number = NSDecimalNumber(decimal: decimal).doubleValue

        if number >= 1000 {
            return String(format: "%.2f", number)
        } else if number >= 1 {
            return String(format: "%.4f", number)
        } else {
            return String(format: "%.6f", number)
        }
    }

    // MARK: - Cleanup

    deinit {
        // Call synchronously - no need for Task since timer invalidation is synchronous
        stopQuoteRefresh()
    }
}

// MARK: - Errors

enum SwapError: LocalizedError {
    case buildFailed(String)
    case signFailed(String)
    case broadcastFailed(String)
    case insufficientBalance
    case invalidAmount

    var errorDescription: String? {
        switch self {
        case .buildFailed(let message):
            return "Failed to build swap: \(message)"
        case .signFailed(let message):
            return "Failed to sign: \(message)"
        case .broadcastFailed(let message):
            return "Failed to broadcast: \(message)"
        case .insufficientBalance:
            return "Insufficient balance"
        case .invalidAmount:
            return "Invalid amount"
        }
    }
}
