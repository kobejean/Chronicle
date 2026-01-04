import Foundation

/// Errors that can occur during time tracking operations
public enum TrackingError: Error, LocalizedError {
    case saveFailed(underlying: Error)
    case taskNotFound(id: UUID)
    case entryNotFound
    case locationNotAuthorized

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        case .entryNotFound:
            return "No active time entry"
        case .locationNotAuthorized:
            return "Location permission not granted"
        }
    }
}
