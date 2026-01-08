import Foundation
import FirebaseCrashlytics
import OSLog

private let logger = Logger(subsystem: "com.syndicatemike.Mimic", category: "ErrorReporter")

/// Centralized error reporting service for crash reporting and analytics
/// Wraps Firebase Crashlytics for production error tracking
@MainActor
final class ErrorReporter {
    static let shared = ErrorReporter()

    private var isEnabled = true
    private var userId: String?

    private init() {}

    // MARK: - Configuration

    /// Configure error reporter with user context
    func configure(userId: String?) {
        self.userId = userId

        if let userId = userId {
            Crashlytics.crashlytics().setUserID(userId)
            logger.debug("ErrorReporter configured for user")
        } else {
            Crashlytics.crashlytics().setUserID("")
            logger.debug("ErrorReporter configured (no user)")
        }
    }

    /// Enable or disable error reporting (e.g., for user privacy settings)
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
        logger.info("Error reporting \(enabled ? "enabled" : "disabled")")
    }

    // MARK: - Error Reporting

    /// Report a non-fatal error with context
    /// Use this for errors that don't crash the app but should be tracked
    func report(
        _ error: Error,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }

        let fileName = (file as NSString).lastPathComponent
        let location = "\(fileName):\(line) \(function)"

        // Log locally
        logger.error("[\(context ?? "Error")] \(error.localizedDescription) at \(location)")

        // Send to Crashlytics
        var userInfo: [String: Any] = [
            "location": location,
            "function": function,
        ]

        if let context = context {
            userInfo["context"] = context
            Crashlytics.crashlytics().setCustomValue(context, forKey: "last_error_context")
        }

        let nsError = NSError(
            domain: "com.syndicatemike.Mimic",
            code: (error as NSError).code,
            userInfo: userInfo.merging((error as NSError).userInfo) { _, new in new }
        )

        Crashlytics.crashlytics().record(error: nsError)
    }

    /// Report a non-fatal error with a message (for custom errors)
    func report(
        message: String,
        code: Int = -1,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }

        let fileName = (file as NSString).lastPathComponent
        let location = "\(fileName):\(line) \(function)"

        // Log locally
        logger.error("[\(context ?? "Error")] \(message) at \(location)")

        // Send to Crashlytics
        let error = NSError(
            domain: "com.syndicatemike.Mimic",
            code: code,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                "location": location,
                "context": context ?? "unknown"
            ]
        )

        Crashlytics.crashlytics().record(error: error)
    }

    // MARK: - Breadcrumbs / Custom Logs

    /// Log a breadcrumb for debugging crash reports
    /// These show up in the Crashlytics dashboard to help trace what happened before a crash
    func log(_ message: String) {
        guard isEnabled else { return }
        Crashlytics.crashlytics().log(message)
        logger.debug("\(message)")
    }

    /// Set a custom key-value pair for crash reports
    func setCustomValue(_ value: Any, forKey key: String) {
        guard isEnabled else { return }
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    // MARK: - User Actions

    /// Track a significant user action (shows in crash reports)
    func trackAction(_ action: String, parameters: [String: Any]? = nil) {
        guard isEnabled else { return }

        var logMessage = "Action: \(action)"
        if let params = parameters {
            logMessage += " params: \(params)"
        }

        Crashlytics.crashlytics().log(logMessage)
        logger.info("\(logMessage)")
    }

    // MARK: - Screen Tracking

    /// Track current screen for crash context
    func setCurrentScreen(_ screenName: String) {
        guard isEnabled else { return }
        Crashlytics.crashlytics().setCustomValue(screenName, forKey: "current_screen")
        logger.debug("Screen: \(screenName)")
    }
}

// MARK: - Convenience Extensions

extension Error {
    /// Report this error to Crashlytics
    func report(context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        Task { @MainActor in
            ErrorReporter.shared.report(self, context: context, file: file, function: function, line: line)
        }
    }
}
