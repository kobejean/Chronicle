import Foundation
import SwiftData

/// Daily or weekly time goal for a task
@Model
public final class Goal {
    public var id: UUID = UUID()

    /// Target time in minutes
    public var targetMinutes: Int = 60

    /// Goal type: "daily" or "weekly"
    public var goalType: GoalType = GoalType.daily

    public var isActive: Bool = true
    public var createdAt: Date = Date()

    public var task: TrackedTask? = nil

    public enum GoalType: String, Codable {
        case daily
        case weekly
    }

    public init(task: TrackedTask?, targetMinutes: Int, goalType: GoalType = .daily) {
        self.id = UUID()
        self.task = task
        self.targetMinutes = targetMinutes
        self.goalType = goalType
        self.createdAt = Date()
    }

    /// Target duration as TimeInterval
    public var targetDuration: TimeInterval {
        TimeInterval(targetMinutes * 60)
    }

    /// Progress percentage (0.0 to 1.0+)
    public var progress: Double {
        guard let task = task else { return 0 }
        let tracked: TimeInterval
        switch goalType {
        case .daily:
            tracked = task.todayDuration
        case .weekly:
            tracked = task.weekDuration
        }
        return tracked / targetDuration
    }

    /// Whether the goal is complete
    public var isComplete: Bool {
        progress >= 1.0
    }

    /// Remaining time to reach goal
    public var remainingDuration: TimeInterval {
        guard let task = task else { return targetDuration }
        let tracked: TimeInterval
        switch goalType {
        case .daily:
            tracked = task.todayDuration
        case .weekly:
            tracked = task.weekDuration
        }
        return max(0, targetDuration - tracked)
    }
}
