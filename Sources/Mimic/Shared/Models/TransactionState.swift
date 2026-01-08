import Foundation

/// Transaction lifecycle state for send/swap operations
enum TransactionState {
    case idle
    case building
    case signing
    case broadcasting
    case confirming
    case completed
    case failed

    var displayMessage: String {
        switch self {
        case .idle:
            return ""
        case .building:
            return "Submitting..."
        case .signing:
            return "Submitting..."
        case .broadcasting:
            return "Submitting..."
        case .confirming:
            return "Submitting..."
        case .completed:
            return "Submitted"
        case .failed:
            return "Failed"
        }
    }
}
