import Foundation
import SwiftData

/// Tracks consecutive days of task completion
@Model
public final class Streak {
    public var id: UUID = UUID()
    public var taskID: UUID = UUID()

    /// Current consecutive days
    public var currentStreak: Int = 0

    /// Longest streak ever achieved
    public var longestStreak: Int = 0

    /// Last date the streak was updated
    public var lastCompletedDate: Date? = nil

    public init(taskID: UUID) {
        self.id = UUID()
        self.taskID = taskID
    }

    /// Check and update streak based on goal completion
    public func updateStreak(goalCompletedToday: Bool) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if goalCompletedToday {
            if let lastDate = lastCompletedDate {
                let lastDay = calendar.startOfDay(for: lastDate)
                let daysDifference = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

                if daysDifference == 1 {
                    // Consecutive day
                    currentStreak += 1
                } else if daysDifference > 1 {
                    // Streak broken, start new
                    currentStreak = 1
                }
                // daysDifference == 0 means already updated today, do nothing
            } else {
                // First completion ever
                currentStreak = 1
            }

            lastCompletedDate = today
            longestStreak = max(longestStreak, currentStreak)
        }
    }

    /// Check if streak is still active (not broken)
    public var isActive: Bool {
        guard let lastDate = lastCompletedDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)
        let daysDifference = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return daysDifference <= 1
    }

    /// Days until streak breaks (0 if already broken)
    public var daysUntilStreakBreaks: Int {
        guard isActive, let lastDate = lastCompletedDate else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)
        let daysDifference = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return daysDifference == 0 ? 1 : 0
    }
}
