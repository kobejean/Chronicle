import Testing
import Foundation
@testable import ChronicleFeature

@Suite("Streak Tests")
struct StreakTests {

    // MARK: - Initial State

    @Test("New streak starts at zero")
    func initialState() {
        let streak = Streak(taskID: UUID())

        #expect(streak.currentStreak == 0)
        #expect(streak.longestStreak == 0)
        #expect(streak.lastCompletedDate == nil)
    }

    // MARK: - updateStreak()

    @Suite("updateStreak")
    struct UpdateStreak {

        @Test("First completion starts streak at 1")
        func firstCompletion() {
            let streak = Streak(taskID: UUID())

            streak.updateStreak(goalCompletedToday: true)

            #expect(streak.currentStreak == 1)
            #expect(streak.longestStreak == 1)
            #expect(streak.lastCompletedDate != nil)
        }

        @Test("Consecutive day increments streak")
        func consecutiveDay() {
            let streak = Streak(taskID: UUID())
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!

            streak.currentStreak = 5
            streak.longestStreak = 5
            streak.lastCompletedDate = yesterday

            streak.updateStreak(goalCompletedToday: true)

            #expect(streak.currentStreak == 6)
            #expect(streak.longestStreak == 6)
        }

        @Test("Streak breaks after missing a day")
        func streakBreaks() {
            let streak = Streak(taskID: UUID())
            let calendar = Calendar.current
            let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: Date()))!

            streak.currentStreak = 10
            streak.longestStreak = 10
            streak.lastCompletedDate = twoDaysAgo

            streak.updateStreak(goalCompletedToday: true)

            #expect(streak.currentStreak == 1) // Reset to 1
            #expect(streak.longestStreak == 10) // Longest preserved
        }

        @Test("Same day completion does not increment streak")
        func sameDayDoesNotIncrement() {
            let streak = Streak(taskID: UUID())
            let today = Calendar.current.startOfDay(for: Date())

            streak.currentStreak = 3
            streak.longestStreak = 3
            streak.lastCompletedDate = today

            streak.updateStreak(goalCompletedToday: true)

            #expect(streak.currentStreak == 3) // Unchanged
            #expect(streak.longestStreak == 3)
        }

        @Test("False completion does not change streak")
        func falseCompletionNoChange() {
            let streak = Streak(taskID: UUID())

            streak.currentStreak = 5
            streak.longestStreak = 5

            streak.updateStreak(goalCompletedToday: false)

            #expect(streak.currentStreak == 5)
            #expect(streak.longestStreak == 5)
        }

        @Test("Longest streak updates when current exceeds it")
        func longestStreakUpdates() {
            let streak = Streak(taskID: UUID())
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!

            streak.currentStreak = 7
            streak.longestStreak = 5 // Previous record
            streak.lastCompletedDate = yesterday

            streak.updateStreak(goalCompletedToday: true)

            #expect(streak.currentStreak == 8)
            #expect(streak.longestStreak == 8) // Updated
        }
    }

    // MARK: - isActive

    @Suite("isActive")
    struct IsActive {

        @Test("isActive is false when never completed")
        func neverCompleted() {
            let streak = Streak(taskID: UUID())

            #expect(streak.isActive == false)
        }

        @Test("isActive is true when completed today")
        func completedToday() {
            let streak = Streak(taskID: UUID())
            streak.lastCompletedDate = Calendar.current.startOfDay(for: Date())
            streak.currentStreak = 1

            #expect(streak.isActive == true)
        }

        @Test("isActive is true when completed yesterday")
        func completedYesterday() {
            let streak = Streak(taskID: UUID())
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
            streak.lastCompletedDate = yesterday
            streak.currentStreak = 1

            #expect(streak.isActive == true)
        }

        @Test("isActive is false when completed 2+ days ago")
        func completedTwoDaysAgo() {
            let streak = Streak(taskID: UUID())
            let calendar = Calendar.current
            let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: Date()))!
            streak.lastCompletedDate = twoDaysAgo
            streak.currentStreak = 5

            #expect(streak.isActive == false)
        }
    }

    // MARK: - daysUntilStreakBreaks

    @Suite("daysUntilStreakBreaks")
    struct DaysUntilBreaks {

        @Test("Returns 0 when no active streak")
        func noActiveStreak() {
            let streak = Streak(taskID: UUID())

            #expect(streak.daysUntilStreakBreaks == 0)
        }

        @Test("Returns 1 when completed today")
        func completedToday() {
            let streak = Streak(taskID: UUID())
            streak.lastCompletedDate = Calendar.current.startOfDay(for: Date())
            streak.currentStreak = 1

            #expect(streak.daysUntilStreakBreaks == 1)
        }

        @Test("Returns 0 when completed yesterday (must complete today)")
        func completedYesterday() {
            let streak = Streak(taskID: UUID())
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
            streak.lastCompletedDate = yesterday
            streak.currentStreak = 1

            #expect(streak.daysUntilStreakBreaks == 0)
        }

        @Test("Returns 0 when streak already broken")
        func alreadyBroken() {
            let streak = Streak(taskID: UUID())
            let calendar = Calendar.current
            let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: Date()))!
            streak.lastCompletedDate = threeDaysAgo
            streak.currentStreak = 5

            #expect(streak.daysUntilStreakBreaks == 0)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCases {

        @Test("Handles long streak correctly")
        func longStreak() {
            let streak = Streak(taskID: UUID())
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!

            streak.currentStreak = 365
            streak.longestStreak = 365
            streak.lastCompletedDate = yesterday

            streak.updateStreak(goalCompletedToday: true)

            #expect(streak.currentStreak == 366)
            #expect(streak.longestStreak == 366)
        }

        @Test("Preserves longest streak after break")
        func preservesLongestAfterBreak() {
            let streak = Streak(taskID: UUID())
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: Date()))!

            streak.currentStreak = 30
            streak.longestStreak = 100
            streak.lastCompletedDate = weekAgo

            streak.updateStreak(goalCompletedToday: true)

            #expect(streak.currentStreak == 1) // Reset
            #expect(streak.longestStreak == 100) // Preserved
        }

        @Test("Multiple updates on same day are idempotent")
        func multipleUpdatesIdempotent() {
            let streak = Streak(taskID: UUID())

            streak.updateStreak(goalCompletedToday: true)
            let afterFirst = streak.currentStreak

            streak.updateStreak(goalCompletedToday: true)
            streak.updateStreak(goalCompletedToday: true)
            streak.updateStreak(goalCompletedToday: true)

            #expect(streak.currentStreak == afterFirst)
        }
    }
}
