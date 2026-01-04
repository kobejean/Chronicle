import Testing
import Foundation
import SwiftData
@testable import ChronicleFeature

@Suite("Goal Tests")
@MainActor
struct GoalTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: TrackedTask.self, TimeEntry.self, PomodoroSettings.self,
            DiaryEntry.self, Goal.self, GPSPoint.self, Place.self, Streak.self,
            configurations: config
        )
    }

    // MARK: - Initialization

    @Test("Goal initializes with correct values")
    func initialization() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 60, goalType: .daily)
        context.insert(goal)

        #expect(goal.targetMinutes == 60)
        #expect(goal.goalType == .daily)
        #expect(goal.isActive == true)
        #expect(goal.task === task)
    }

    @Test("Goal defaults to daily type")
    func defaultsToDaily() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 30)
        context.insert(goal)

        #expect(goal.goalType == .daily)
    }

    // MARK: - targetDuration

    @Test("targetDuration converts minutes to seconds")
    func targetDurationConversion() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 45)
        context.insert(goal)

        #expect(goal.targetDuration == 2700) // 45 * 60
    }

    // MARK: - progress (Daily)

    @Test("progress is 0 with no tracked time")
    func noProgress() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 60, goalType: .daily)
        context.insert(goal)
        try context.save()

        #expect(goal.progress == 0.0)
    }

    @Test("progress is 0.5 at 50% of goal")
    func halfProgress() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        // 60 minute goal
        let goal = Goal(task: task, targetMinutes: 60, goalType: .daily)
        context.insert(goal)

        // Add 30 minutes of time today
        let now = Date()
        let entry = TimeEntry(task: task, startTime: now.addingTimeInterval(-1800))
        entry.endTime = now
        context.insert(entry)

        try context.save()

        #expect(goal.progress >= 0.49 && goal.progress <= 0.51)
    }

    @Test("progress is 1.0 at 100% of goal")
    func fullProgress() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        // 30 minute goal
        let goal = Goal(task: task, targetMinutes: 30, goalType: .daily)
        context.insert(goal)

        // Add exactly 30 minutes of time today
        let now = Date()
        let entry = TimeEntry(task: task, startTime: now.addingTimeInterval(-1800))
        entry.endTime = now
        context.insert(entry)

        try context.save()

        #expect(goal.progress >= 0.99 && goal.progress <= 1.01)
    }

    @Test("progress exceeds 1.0 when goal exceeded")
    func exceededProgress() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        // 30 minute goal
        let goal = Goal(task: task, targetMinutes: 30, goalType: .daily)
        context.insert(goal)

        // Add 60 minutes of time today (2x goal)
        let now = Date()
        let entry = TimeEntry(task: task, startTime: now.addingTimeInterval(-3600))
        entry.endTime = now
        context.insert(entry)

        try context.save()

        #expect(goal.progress >= 1.99 && goal.progress <= 2.01)
    }

    @Test("progress is 0 when no task associated")
    func noTask() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let goal = Goal(task: nil, targetMinutes: 60)
        context.insert(goal)
        try context.save()

        #expect(goal.progress == 0.0)
    }

    // MARK: - progress (Weekly)

    @Test("weekly progress uses weekDuration")
    func usesWeekDuration() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        // 5 hour weekly goal (300 minutes)
        let goal = Goal(task: task, targetMinutes: 300, goalType: .weekly)
        context.insert(goal)

        // Add 1 hour today
        let now = Date()
        let entry = TimeEntry(task: task, startTime: now.addingTimeInterval(-3600))
        entry.endTime = now
        context.insert(entry)

        try context.save()

        // 1 hour of 5 hours = 20%
        #expect(goal.progress >= 0.19 && goal.progress <= 0.21)
    }

    // MARK: - isComplete

    @Test("isComplete is false below 100%")
    func notCompleteBelow100() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 60, goalType: .daily)
        context.insert(goal)

        // Only 30 minutes tracked
        let now = Date()
        let entry = TimeEntry(task: task, startTime: now.addingTimeInterval(-1800))
        entry.endTime = now
        context.insert(entry)

        try context.save()

        #expect(goal.isComplete == false)
    }

    @Test("isComplete is true at 100%")
    func completeAt100() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 30, goalType: .daily)
        context.insert(goal)

        // Exactly 30 minutes
        let now = Date()
        let entry = TimeEntry(task: task, startTime: now.addingTimeInterval(-1800))
        entry.endTime = now
        context.insert(entry)

        try context.save()

        #expect(goal.isComplete == true)
    }

    @Test("isComplete is true above 100%")
    func completeAbove100() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 15, goalType: .daily)
        context.insert(goal)

        // 30 minutes (2x goal)
        let now = Date()
        let entry = TimeEntry(task: task, startTime: now.addingTimeInterval(-1800))
        entry.endTime = now
        context.insert(entry)

        try context.save()

        #expect(goal.isComplete == true)
    }

    // MARK: - remainingDuration

    @Test("remainingDuration equals targetDuration with no progress")
    func noProgressRemaining() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 60, goalType: .daily)
        context.insert(goal)
        try context.save()

        #expect(goal.remainingDuration == 3600)
    }

    @Test("remainingDuration decreases with progress")
    func partialProgressRemaining() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 60, goalType: .daily)
        context.insert(goal)

        // 30 minutes done
        let now = Date()
        let entry = TimeEntry(task: task, startTime: now.addingTimeInterval(-1800))
        entry.endTime = now
        context.insert(entry)

        try context.save()

        // Should be approximately 30 minutes remaining
        #expect(goal.remainingDuration >= 1799 && goal.remainingDuration <= 1801)
    }

    @Test("remainingDuration is zero when goal complete")
    func zeroWhenComplete() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 30, goalType: .daily)
        context.insert(goal)

        // Exactly 30 minutes
        let now = Date()
        let entry = TimeEntry(task: task, startTime: now.addingTimeInterval(-1800))
        entry.endTime = now
        context.insert(entry)

        try context.save()

        #expect(goal.remainingDuration >= 0 && goal.remainingDuration <= 1)
    }

    @Test("remainingDuration never goes negative")
    func neverNegative() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let goal = Goal(task: task, targetMinutes: 15, goalType: .daily)
        context.insert(goal)

        // 60 minutes (4x the goal)
        let now = Date()
        let entry = TimeEntry(task: task, startTime: now.addingTimeInterval(-3600))
        entry.endTime = now
        context.insert(entry)

        try context.save()

        #expect(goal.remainingDuration == 0)
    }

    @Test("remainingDuration returns targetDuration when no task")
    func noTaskReturnsTarget() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let goal = Goal(task: nil, targetMinutes: 60)
        context.insert(goal)
        try context.save()

        #expect(goal.remainingDuration == 3600)
    }

    // MARK: - GoalType

    @Test("GoalType raw values are correct")
    func rawValues() {
        #expect(Goal.GoalType.daily.rawValue == "daily")
        #expect(Goal.GoalType.weekly.rawValue == "weekly")
    }

    @Test("GoalType is Codable")
    func isCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let daily = Goal.GoalType.daily
        let data = try encoder.encode(daily)
        let decoded = try decoder.decode(Goal.GoalType.self, from: data)

        #expect(decoded == daily)
    }
}
