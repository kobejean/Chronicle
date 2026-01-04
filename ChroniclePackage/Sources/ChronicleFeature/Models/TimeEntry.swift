import Foundation
import SwiftData

/// A single time tracking entry representing time spent on a task
@Model
public final class TimeEntry {
    public var id: UUID = UUID()
    public var startTime: Date = Date()
    public var endTime: Date? = nil
    public var notes: String? = nil

    public var task: TrackedTask? = nil

    @Relationship(deleteRule: .cascade, inverse: \GPSPoint.timeEntry)
    public var gpsTrail: [GPSPoint]? = []

    public var place: Place? = nil

    /// Duration of this entry in seconds
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// Whether this entry is currently running
    public var isRunning: Bool {
        endTime == nil
    }

    /// Formatted duration string (e.g., "1h 23m")
    public var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    public init(task: TrackedTask?, startTime: Date = Date()) {
        self.id = UUID()
        self.task = task
        self.startTime = startTime
    }

    /// Stop this time entry
    public func stop() {
        if endTime == nil {
            endTime = Date()
        }
    }
}
