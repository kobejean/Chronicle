import Foundation
import SwiftData

/// Protocol for controlling task tracking operations
/// Used by GeofenceManager to trigger task start/stop without tight coupling to TimeTracker
@MainActor
public protocol TaskController: AnyObject {
    /// Start tracking a task by its ID
    func startTaskByID(_ id: UUID, in context: ModelContext)

    /// Stop the currently active time entry
    func stopCurrentEntry(in context: ModelContext)
}
