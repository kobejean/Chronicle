import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import ChronicleFeature

@Suite("TrackedTask Tests")
@MainActor
struct TrackedTaskTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: TrackedTask.self, TimeEntry.self, PomodoroSettings.self,
            DiaryEntry.self, Goal.self, GPSPoint.self, Place.self, Streak.self,
            configurations: config
        )
    }

    // MARK: - Initialization

    @Test("Task initializes with correct values")
    func initialization() {
        let task = TrackedTask(name: "Work", colorHex: "#FF0000", iconName: "briefcase")

        #expect(task.name == "Work")
        #expect(task.colorHex == "#FF0000")
        #expect(task.iconName == "briefcase")
        #expect(task.isFavorite == false)
        #expect(task.isArchived == false)
        #expect(task.sortOrder == 0)
    }

    @Test("Task uses default color hex")
    func defaultColorHex() {
        let task = TrackedTask(name: "Default")

        #expect(task.colorHex == "#007AFF")
    }

    @Test("Task color computed property works")
    func colorProperty() {
        let task = TrackedTask(name: "Test", colorHex: "#FF0000")

        // Should return a valid color
        _ = task.color // Just verify it doesn't crash
    }

    @Test("Task color falls back to blue for invalid hex")
    func colorFallback() {
        let task = TrackedTask(name: "Test", colorHex: "invalid")

        // The color property uses a fallback
        let color = task.color
        #expect(color == .blue)
    }

    // MARK: - todayDuration with SwiftData

    @Test("todayDuration is zero with no entries")
    func noEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)
        try context.save()

        #expect(task.todayDuration == 0)
    }

    @Test("todayDuration sums today's completed entries")
    func sumsCompletedEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        // Create two 30-minute entries today
        let now = Date()
        let entry1 = TimeEntry(task: task, startTime: now.addingTimeInterval(-3600))
        entry1.endTime = now.addingTimeInterval(-1800) // 30 min duration
        context.insert(entry1)

        let entry2 = TimeEntry(task: task, startTime: now.addingTimeInterval(-1800))
        entry2.endTime = now // 30 min duration
        context.insert(entry2)

        try context.save()

        #expect(task.todayDuration == 3600) // 60 min total
    }

    @Test("todayDuration excludes entries from other days")
    func excludesOtherDays() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let now = Date()

        // Entry from today
        let todayEntry = TimeEntry(task: task, startTime: now.addingTimeInterval(-1800))
        todayEntry.endTime = now
        context.insert(todayEntry)

        // Entry from yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let yesterdayEntry = TimeEntry(task: task, startTime: yesterday)
        yesterdayEntry.endTime = yesterday.addingTimeInterval(3600)
        context.insert(yesterdayEntry)

        try context.save()

        #expect(task.todayDuration == 1800) // Only today's 30 min
    }

    @Test("todayDuration includes running entries")
    func includesRunningEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        // Running entry started 30 min ago
        let entry = TimeEntry(task: task, startTime: Date().addingTimeInterval(-1800))
        // No endTime - still running
        context.insert(entry)

        try context.save()

        // Should be approximately 30 min
        #expect(task.todayDuration >= 1799 && task.todayDuration <= 1801)
    }

    // MARK: - weekDuration with SwiftData

    @Test("weekDuration is zero with no entries")
    func weekNoEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)
        try context.save()

        #expect(task.weekDuration == 0)
    }

    @Test("weekDuration sums this week's entries")
    func sumsWeekEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let now = Date()

        // Today's entry
        let todayEntry = TimeEntry(task: task, startTime: now.addingTimeInterval(-3600))
        todayEntry.endTime = now
        context.insert(todayEntry)

        try context.save()

        // Should include today's 1 hour
        #expect(task.weekDuration >= 3599 && task.weekDuration <= 3601)
    }

    @Test("weekDuration excludes entries from previous weeks")
    func excludesPreviousWeeks() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let task = TrackedTask(name: "Test")
        context.insert(task)

        let now = Date()

        // Entry from today
        let todayEntry = TimeEntry(task: task, startTime: now.addingTimeInterval(-1800))
        todayEntry.endTime = now
        context.insert(todayEntry)

        // Entry from 2 weeks ago
        let twoWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: now)!
        let oldEntry = TimeEntry(task: task, startTime: twoWeeksAgo)
        oldEntry.endTime = twoWeeksAgo.addingTimeInterval(7200)
        context.insert(oldEntry)

        try context.save()

        // Should only include today's 30 min
        #expect(task.weekDuration >= 1799 && task.weekDuration <= 1801)
    }
}
