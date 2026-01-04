import Testing
import Foundation
import SwiftData
@testable import ChronicleFeature

@Suite("TimeTracker")
@MainActor
struct TimeTrackerTests {

    // MARK: - Test Helpers

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TrackedTask.self, TimeEntry.self, PomodoroSettings.self, GPSPoint.self,
            configurations: config
        )
        return container.mainContext
    }

    // MARK: - Initial State

    @Test("Initial state has no active entry")
    func initialState() {
        let tracker = TimeTracker()
        #expect(tracker.activeEntry == nil)
        #expect(tracker.pomodoroState == .idle)
    }

    @Test("GPS trail is disabled by default")
    func gpsDisabledByDefault() {
        let tracker = TimeTracker()
        #expect(tracker.isGPSTrailEnabled == false)
    }

    // MARK: - Starting Tasks

    @Test("Starting task creates active entry")
    func startTask() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Test Task")
        context.insert(task)

        tracker.startTask(task, in: context)

        #expect(tracker.activeEntry != nil)
        #expect(tracker.activeEntry?.task?.id == task.id)
        #expect(tracker.activeEntry?.endTime == nil)
    }

    @Test("Starting task sets correct start time")
    func startTaskSetsTime() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Test Task")
        context.insert(task)

        let before = Date()
        tracker.startTask(task, in: context)
        let after = Date()

        #expect(tracker.activeEntry?.startTime != nil)
        #expect(tracker.activeEntry!.startTime >= before)
        #expect(tracker.activeEntry!.startTime <= after)
    }

    @Test("Starting task by ID works")
    func startTaskByID() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Test Task")
        context.insert(task)
        try context.save()

        tracker.startTaskByID(task.id, in: context)

        #expect(tracker.activeEntry != nil)
        #expect(tracker.activeEntry?.task?.id == task.id)
    }

    @Test("Starting task by unknown ID does nothing")
    func startTaskByUnknownID() throws {
        let context = try makeContext()
        let tracker = TimeTracker()

        tracker.startTaskByID(UUID(), in: context)

        #expect(tracker.activeEntry == nil)
    }

    // MARK: - Stopping Tasks

    @Test("Stopping clears active entry")
    func stopTask() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Test Task")
        context.insert(task)

        tracker.startTask(task, in: context)
        tracker.stopCurrentEntry(in: context)

        #expect(tracker.activeEntry == nil)
    }

    @Test("Stopping sets end time on entry")
    func stopSetsEndTime() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Test Task")
        context.insert(task)

        tracker.startTask(task, in: context)
        let entry = tracker.activeEntry!

        tracker.stopCurrentEntry(in: context)

        #expect(entry.endTime != nil)
    }

    @Test("Stopping when nothing active does nothing")
    func stopWhenNoActive() throws {
        let context = try makeContext()
        let tracker = TimeTracker()

        tracker.stopCurrentEntry(in: context) // Should not crash

        #expect(tracker.activeEntry == nil)
    }

    // MARK: - Switching Tasks

    @Test("Starting new task stops previous")
    func startNewStopsPrevious() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task1 = TrackedTask(name: "Task 1")
        let task2 = TrackedTask(name: "Task 2")
        context.insert(task1)
        context.insert(task2)

        tracker.startTask(task1, in: context)
        let firstEntry = tracker.activeEntry

        tracker.startTask(task2, in: context)

        #expect(firstEntry?.endTime != nil) // First was stopped
        #expect(tracker.activeEntry?.task?.id == task2.id)
    }

    @Test("Switch task convenience method works")
    func switchTask() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task1 = TrackedTask(name: "Task 1")
        let task2 = TrackedTask(name: "Task 2")
        context.insert(task1)
        context.insert(task2)

        tracker.startTask(task1, in: context)
        tracker.switchTask(to: task2, in: context)

        #expect(tracker.activeEntry?.task?.id == task2.id)
    }

    // MARK: - isTracking

    @Test("isTracking returns true for active task")
    func isTrackingActive() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Test Task")
        context.insert(task)

        tracker.startTask(task, in: context)

        #expect(tracker.isTracking(task) == true)
    }

    @Test("isTracking returns false for inactive task")
    func isTrackingInactive() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task1 = TrackedTask(name: "Task 1")
        let task2 = TrackedTask(name: "Task 2")
        context.insert(task1)
        context.insert(task2)

        tracker.startTask(task1, in: context)

        #expect(tracker.isTracking(task2) == false)
    }

    @Test("isTracking returns false when nothing active")
    func isTrackingWhenNoneActive() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Test Task")
        context.insert(task)

        #expect(tracker.isTracking(task) == false)
    }

    // MARK: - Pomodoro Integration

    @Test("Starting task with pomodoro activates timer")
    func startWithPomodoro() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Focus Task")
        let settings = PomodoroSettings()
        settings.isEnabled = true
        task.pomodoroSettings = settings
        context.insert(task)

        tracker.startTask(task, in: context)

        #expect(tracker.pomodoroState != .idle)
        #expect(tracker.pomodoroPhaseEndTime != nil)
    }

    @Test("Starting task without pomodoro keeps idle state")
    func startWithoutPomodoro() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Regular Task")
        context.insert(task)

        tracker.startTask(task, in: context)

        #expect(tracker.pomodoroState == .idle)
        #expect(tracker.pomodoroPhaseEndTime == nil)
    }

    @Test("Stopping task stops pomodoro")
    func stopWithPomodoro() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Focus Task")
        let settings = PomodoroSettings()
        settings.isEnabled = true
        task.pomodoroSettings = settings
        context.insert(task)

        tracker.startTask(task, in: context)
        tracker.stopCurrentEntry(in: context)

        #expect(tracker.pomodoroState == .idle)
        #expect(tracker.pomodoroPhaseEndTime == nil)
    }

    @Test("Pomodoro controls delegate correctly")
    func pomodoroControls() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Focus Task")
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4
        settings.autoStartBreaks = true
        task.pomodoroSettings = settings
        context.insert(task)

        tracker.startTask(task, in: context)
        #expect(tracker.pomodoroState == .working(sessionNumber: 1, totalSessions: 4))

        tracker.skipPomodoroPhase()
        #expect(tracker.pomodoroState == .shortBreak(afterSession: 1))

        tracker.resetPomodoro()
        #expect(tracker.pomodoroState == .working(sessionNumber: 1, totalSessions: 4))
    }

    // MARK: - Load Active Entry

    @Test("loadActiveEntry restores running entry")
    func loadActiveEntry() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Running Task")
        context.insert(task)

        // Create a running entry directly
        let entry = TimeEntry(task: task, startTime: Date())
        context.insert(entry)
        try context.save()

        // New tracker should find it
        let newTracker = TimeTracker()
        newTracker.loadActiveEntry(from: context)

        #expect(newTracker.activeEntry != nil)
        #expect(newTracker.activeEntry?.id == entry.id)
    }

    @Test("loadActiveEntry ignores completed entries")
    func loadIgnoresCompleted() throws {
        let context = try makeContext()
        let task = TrackedTask(name: "Completed Task")
        context.insert(task)

        // Create a completed entry
        let entry = TimeEntry(task: task, startTime: Date())
        entry.stop()
        context.insert(entry)
        try context.save()

        let tracker = TimeTracker()
        tracker.loadActiveEntry(from: context)

        #expect(tracker.activeEntry == nil)
    }

    @Test("loadActiveEntry restores pomodoro if enabled")
    func loadRestoresPomodoro() throws {
        let context = try makeContext()
        let task = TrackedTask(name: "Focus Task")
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4
        task.pomodoroSettings = settings
        context.insert(task)

        // Create a running entry
        let entry = TimeEntry(task: task, startTime: Date())
        context.insert(entry)
        try context.save()

        let tracker = TimeTracker()
        tracker.loadActiveEntry(from: context)

        #expect(tracker.pomodoroState != .idle)
    }
}
