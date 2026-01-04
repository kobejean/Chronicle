import Foundation
import SwiftData

/// Task-specific Pomodoro timer settings
@Model
public final class PomodoroSettings {
    public var id: UUID = UUID()

    /// Work duration in minutes
    public var workDuration: Int = 25

    /// Short break duration in minutes
    public var shortBreakDuration: Int = 5

    /// Long break duration in minutes
    public var longBreakDuration: Int = 15

    /// Number of work sessions before a long break
    public var sessionsBeforeLongBreak: Int = 4

    /// Whether Pomodoro is enabled for this task
    public var isEnabled: Bool = false

    /// Auto-start breaks after work session
    public var autoStartBreaks: Bool = true

    /// Auto-start work after break
    public var autoStartWork: Bool = false

    public var task: TrackedTask? = nil

    public init() {
        self.id = UUID()
    }

    /// Work duration as TimeInterval
    public var workTimeInterval: TimeInterval {
        TimeInterval(workDuration * 60)
    }

    /// Short break duration as TimeInterval
    public var shortBreakTimeInterval: TimeInterval {
        TimeInterval(shortBreakDuration * 60)
    }

    /// Long break duration as TimeInterval
    public var longBreakTimeInterval: TimeInterval {
        TimeInterval(longBreakDuration * 60)
    }
}
