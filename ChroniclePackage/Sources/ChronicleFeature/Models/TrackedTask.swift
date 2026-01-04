import SwiftUI
import SwiftData

/// A task that can be tracked for time logging
/// Named TrackedTask to avoid conflict with Swift.Task
@Model
public final class TrackedTask {
    public var id: UUID = UUID()
    public var name: String = ""
    public var colorHex: String = "#007AFF"
    public var iconName: String? = nil
    public var isFavorite: Bool = false
    public var isArchived: Bool = false
    public var createdAt: Date = Date()
    public var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.task)
    public var timeEntries: [TimeEntry]? = []

    @Relationship(deleteRule: .cascade, inverse: \PomodoroSettings.task)
    public var pomodoroSettings: PomodoroSettings? = nil

    @Relationship(inverse: \DiaryEntry.task)
    public var diaryEntries: [DiaryEntry]? = []

    @Relationship(deleteRule: .cascade, inverse: \Goal.task)
    public var goals: [Goal]? = []

    public var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    public init(name: String, colorHex: String = "#007AFF", iconName: String? = nil) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.createdAt = Date()
    }

    /// Total time tracked today
    public var todayDuration: TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (timeEntries ?? [])
            .filter { calendar.isDate($0.startTime, inSameDayAs: today) }
            .reduce(0) { $0 + $1.duration }
    }

    /// Total time tracked this week
    public var weekDuration: TimeInterval {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return 0
        }
        return (timeEntries ?? [])
            .filter { $0.startTime >= weekStart }
            .reduce(0) { $0 + $1.duration }
    }
}
