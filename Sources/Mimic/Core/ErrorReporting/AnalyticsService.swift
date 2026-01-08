import Foundation
import FirebaseAnalytics
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "Analytics")

/// Analytics service for tracking user behavior and feature usage
/// Wraps Firebase Analytics for production metrics
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var isEnabled = true

    private init() {}

    // MARK: - Configuration

    /// Enable or disable analytics (e.g., for user privacy settings)
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Analytics.setAnalyticsCollectionEnabled(enabled)
        logger.info("Analytics \(enabled ? "enabled" : "disabled")")
    }

    /// Set user ID for analytics
    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }

    /// Set a user property
    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    // MARK: - Screen Tracking

    /// Track screen view
    func trackScreen(_ screenName: String, screenClass: String? = nil) {
        guard isEnabled else { return }

        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])

        logger.debug("Screen: \(screenName)")
    }

    // MARK: - Event Tracking

    /// Track a custom event
    func track(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {
        guard isEnabled else { return }

        Analytics.logEvent(event.rawValue, parameters: parameters)
        logger.debug("Event: \(event.rawValue)")
    }

    /// Track a custom event with string name
    func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
        guard isEnabled else { return }

        Analytics.logEvent(name, parameters: parameters)
        logger.debug("Event: \(name)")
    }

    // MARK: - Predefined Events

    /// Track successful sign in
    func trackSignIn(method: String) {
        track(.signIn, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    /// Track sign out
    func trackSignOut() {
        track(.signOut)
    }

    /// Track wallet connection
    func trackWalletConnected(walletAddress: String) {
        track(.walletConnected, parameters: [
            "wallet_prefix": String(walletAddress.prefix(8))
        ])
    }

    /// Track copy trade action
    func trackCopyTrade(amount: Double, direction: String, market: String) {
        track(.copyTradeExecuted, parameters: [
            "amount": amount,
            "direction": direction,
            "market_prefix": String(market.prefix(8))
        ])
    }

    /// Track prediction bet placed
    func trackPredictionBet(amount: Double, direction: String) {
        track(.predictionBetPlaced, parameters: [
            "amount": amount,
            "direction": direction
        ])
    }

    /// Track onramp started
    func trackOnrampStarted(amount: Double, asset: String) {
        track(.onrampStarted, parameters: [
            "amount": amount,
            "asset": asset
        ])
    }

    /// Track onramp completed
    func trackOnrampCompleted(amount: Double, asset: String) {
        track(.onrampCompleted, parameters: [
            "amount": amount,
            "asset": asset
        ])
    }

    /// Track delegation enabled
    func trackDelegationEnabled(type: String) {
        track(.delegationEnabled, parameters: [
            "type": type
        ])
    }

    /// Track error occurrence (non-fatal)
    func trackError(domain: String, code: Int, context: String?) {
        track(.errorOccurred, parameters: [
            "domain": domain,
            "code": code,
            "context": context ?? "unknown"
        ])
    }
}

// MARK: - Analytics Events

enum AnalyticsEvent: String {
    // Authentication
    case signIn = "sign_in"
    case signOut = "sign_out"
    case walletConnected = "wallet_connected"

    // Predictions
    case predictionBetPlaced = "prediction_bet_placed"
    case predictionBetWon = "prediction_bet_won"
    case predictionBetLost = "prediction_bet_lost"

    // Copy Trading
    case copyTradeExecuted = "copy_trade_executed"
    case trackerAdded = "tracker_added"
    case trackerRemoved = "tracker_removed"
    case delegationEnabled = "delegation_enabled"
    case delegationDisabled = "delegation_disabled"

    // Onramp/Offramp
    case onrampStarted = "onramp_started"
    case onrampCompleted = "onramp_completed"
    case onrampFailed = "onramp_failed"

    // Errors
    case errorOccurred = "error_occurred"

    // Feature Usage
    case featureUsed = "feature_used"
    case settingsChanged = "settings_changed"
}
