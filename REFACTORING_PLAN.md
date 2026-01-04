# Chronicle Architecture Refactoring Plan

## Overview

A **Test-Driven Development (TDD)** approach to incrementally improve the Chronicle codebase's testability and maintainability.

### Guiding Principles

1. **Red-Green-Refactor**: Write failing tests first, implement to pass, then refactor
2. **Keep It Simple**: Avoid abstractions until they prove necessary
3. **Incremental Changes**: Each phase should leave the app fully functional
4. **Test What Matters**: Focus on business logic, not framework integration

### Current Pain Points

| Issue | Location | Impact |
|-------|----------|--------|
| Monolithic TimeTracker | `TimeTracker.swift` (485 lines) | Hard to test, multiple responsibilities |
| Callback coupling | Services use closure callbacks | Initialization order dependencies |
| No service tests | `Tests/` directory | Only models are tested |
| Silent error handling | `try? context.save()` | Bugs go unnoticed |

### What We're NOT Doing

These patterns add complexity without proportional benefit for an app of this size:

- ❌ **Event Bus / Message Passing**: SwiftUI's `@Observable` already handles reactivity
- ❌ **Full Repository Pattern**: SwiftData + `@Query` is sufficient for views; only abstract where needed for testing
- ❌ **Formal DI Container**: SwiftUI's `@Environment` is already dependency injection

---

## Phase 1: Extract PomodoroTimer Service

**Goal**: Extract pomodoro logic from TimeTracker into a dedicated, testable service

### Why This First?
- Pomodoro is self-contained (~150 lines, no external dependencies)
- Easy to test in isolation
- Clear single responsibility
- Biggest complexity reduction for TimeTracker

### 1.1 Write PomodoroTimer Tests (Red)

```swift
// Tests/ChronicleFeatureTests/PomodoroTimerTests.swift

import Testing
import Foundation
@testable import ChronicleFeature

@Suite("PomodoroTimer")
@MainActor
struct PomodoroTimerTests {

    @Test("Initial state is idle")
    func initialState() {
        let timer = PomodoroTimer()
        #expect(timer.state == .idle)
        #expect(timer.phaseEndTime == nil)
    }

    @Test("Starting begins work phase")
    func startBeginsWork() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4

        timer.start(with: settings)

        #expect(timer.state == .working(sessionNumber: 1, totalSessions: 4))
        #expect(timer.phaseEndTime != nil)
    }

    @Test("Stop resets to idle")
    func stopResets() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        timer.start(with: settings)

        timer.stop()

        #expect(timer.state == .idle)
        #expect(timer.phaseEndTime == nil)
    }

    @Test("Skip advances to next phase")
    func skipAdvances() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4
        timer.start(with: settings)

        timer.skip()

        #expect(timer.state == .shortBreak(afterSession: 1))
    }

    @Test("After all sessions, skip goes to long break")
    func skipToLongBreak() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 2
        timer.start(with: settings)

        // Session 1 -> short break
        timer.skip()
        #expect(timer.state == .shortBreak(afterSession: 1))

        // Short break -> Session 2
        timer.skip()
        #expect(timer.state == .working(sessionNumber: 2, totalSessions: 2))

        // Session 2 -> long break
        timer.skip()
        #expect(timer.state == .longBreak)
    }

    @Test("Progress is 0 when idle")
    func progressIdle() {
        let timer = PomodoroTimer()
        #expect(timer.progress == 0)
    }

    @Test("Time remaining is 0 when idle")
    func timeRemainingIdle() {
        let timer = PomodoroTimer()
        #expect(timer.timeRemaining == 0)
    }
}
```

### 1.2 Implement PomodoroTimer (Green)

Create `Sources/ChronicleFeature/Services/PomodoroTimer.swift`:

- Move `PomodoroState` enum from TimeTracker
- Move phase transition logic
- Move timer management
- Move notification scheduling

### 1.3 Integrate into TimeTracker (Refactor)

Update TimeTracker to:
- Accept `PomodoroTimer` as a dependency (with default)
- Delegate all pomodoro operations to it
- Expose pomodoro state via computed properties

```swift
public init(pomodoroTimer: PomodoroTimer = PomodoroTimer()) {
    self.pomodoroTimer = pomodoroTimer
}

public var pomodoroState: PomodoroState { pomodoroTimer.state }
public var pomodoroTimeRemaining: TimeInterval { pomodoroTimer.timeRemaining }
```

### 1.4 Acceptance Criteria

- [ ] All PomodoroTimer tests pass
- [ ] Existing PomodoroTests.swift still passes (may need import updates)
- [ ] App behavior unchanged
- [ ] TimeTracker reduced by ~150 lines

---

## Phase 2: Add TimeTracker Core Tests

**Goal**: Test TimeTracker's core time-tracking behavior using in-memory SwiftData

### Why?
- TimeTracker is the central service but has no tests
- With PomodoroTimer extracted, the remaining logic is more focused
- SwiftData's in-memory containers make this testable

### 2.1 Write TimeTracker Tests

```swift
// Tests/ChronicleFeatureTests/TimeTrackerTests.swift

import Testing
import Foundation
import SwiftData
@testable import ChronicleFeature

@Suite("TimeTracker")
@MainActor
struct TimeTrackerTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TrackedTask.self, TimeEntry.self, PomodoroSettings.self,
            configurations: config
        )
        return container.mainContext
    }

    @Test("Initial state has no active entry")
    func initialState() {
        let tracker = TimeTracker()
        #expect(tracker.activeEntry == nil)
    }

    @Test("Starting task creates active entry")
    func startTask() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Test")
        context.insert(task)

        tracker.startTask(task, in: context)

        #expect(tracker.activeEntry != nil)
        #expect(tracker.activeEntry?.task?.id == task.id)
    }

    @Test("Stopping clears active entry")
    func stopTask() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Test")
        context.insert(task)

        tracker.startTask(task, in: context)
        tracker.stopCurrentEntry(in: context)

        #expect(tracker.activeEntry == nil)
    }

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

    @Test("isTracking returns true for active task")
    func isTrackingActive() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Test")
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

    @Test("Starting task with pomodoro activates timer")
    func startWithPomodoro() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Focus")
        let settings = PomodoroSettings()
        settings.isEnabled = true
        task.pomodoroSettings = settings
        context.insert(task)

        tracker.startTask(task, in: context)

        #expect(tracker.pomodoroState != .idle)
    }

    @Test("Stopping task stops pomodoro")
    func stopWithPomodoro() throws {
        let context = try makeContext()
        let tracker = TimeTracker()
        let task = TrackedTask(name: "Focus")
        let settings = PomodoroSettings()
        settings.isEnabled = true
        task.pomodoroSettings = settings
        context.insert(task)

        tracker.startTask(task, in: context)
        tracker.stopCurrentEntry(in: context)

        #expect(tracker.pomodoroState == .idle)
    }
}
```

### 2.2 Acceptance Criteria

- [ ] All TimeTracker tests pass
- [ ] Tests cover core start/stop/switch behavior
- [ ] Tests verify pomodoro integration
- [ ] No changes to production code (tests document existing behavior)

---

## Phase 3: Simplify Service Dependencies

**Goal**: Replace callback-based coupling with simpler direct dependencies

### Current Problem

```swift
// TimeTracker.swift - configureLocation sets up callbacks
service.onLocationUpdate = { [weak self] location in ... }
geofence.onStartTask = { [weak self] taskID in ... }

// GeofenceManager.swift - also sets up callbacks
locationService.onGeofenceEnter = { [weak self] regionID in ... }
```

This creates:
- Initialization order dependencies
- Circular reference risks
- Hard to test

### Simpler Approach

Instead of callbacks, use direct method calls with protocol abstractions only where needed for testing.

### 3.1 LocationService: Keep Simple

LocationService doesn't need to change much. It's already clean:
- Wraps CLLocationManager
- Publishes state via `@Observable`
- The callbacks are only used by TimeTracker for GPS trails

**Change**: Move GPS trail recording to TimeTracker itself, polling location when needed:

```swift
// TimeTracker can observe locationService.currentLocation directly
// No callback needed - @Observable handles updates
```

### 3.2 GeofenceManager: Inject TimeTracker Protocol

Instead of callbacks, have GeofenceManager call TimeTracker directly through a protocol:

```swift
// Protocol for what GeofenceManager needs
public protocol TaskController: AnyObject {
    func startTaskByID(_ id: UUID)
    func stopCurrentEntry()
}

// GeofenceManager uses the protocol
public final class GeofenceManager {
    private weak var taskController: TaskController?

    public func configure(taskController: TaskController, ...) {
        self.taskController = taskController
    }

    private func handleGeofenceEnter(regionID: String) {
        // Direct call instead of callback
        taskController?.startTaskByID(taskID)
    }
}

// TimeTracker conforms
extension TimeTracker: TaskController { ... }
```

### 3.3 Acceptance Criteria

- [ ] No more `onXxx` callback properties on services
- [ ] Services use direct calls via protocols
- [ ] TimeTracker tests can use mock TaskController if needed
- [ ] Initialization order no longer matters

---

## Phase 4: Improve Error Handling

**Goal**: Replace silent `try?` failures with proper error handling

### Current Problem

```swift
try? context.save()  // Silent failures - bugs go unnoticed
```

### 4.1 Add Error Types

```swift
// Sources/ChronicleFeature/Errors/TrackingError.swift

public enum TrackingError: Error, LocalizedError {
    case saveFailed(underlying: Error)
    case taskNotFound(id: UUID)
    case entryNotFound

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        case .entryNotFound:
            return "No active time entry"
        }
    }
}
```

### 4.2 Update TimeTracker Methods

Change critical operations to throw or return Result:

```swift
public func startTask(_ task: TrackedTask, in context: ModelContext) throws {
    // ... existing logic ...
    do {
        try context.save()
    } catch {
        throw TrackingError.saveFailed(underlying: error)
    }
}
```

Or use logging for non-critical failures:

```swift
do {
    try context.save()
} catch {
    // Log but don't crash - widget sync failure isn't critical
    print("Warning: Failed to save context: \(error)")
}
```

### 4.3 Acceptance Criteria

- [ ] Critical operations (start/stop task) throw on failure
- [ ] Non-critical operations log warnings
- [ ] Views handle errors appropriately
- [ ] No more unexplained data loss

---

## Summary

| Phase | Goal | Key Change |
|-------|------|------------|
| **1** | Extract PomodoroTimer | Reduce TimeTracker by ~150 lines, enable pomodoro testing |
| **2** | Test TimeTracker | Document core behavior with tests |
| **3** | Simplify dependencies | Replace callbacks with direct protocol-based calls |
| **4** | Error handling | Replace `try?` with proper error handling |

### Success Metrics

| Metric | Before | After |
|--------|--------|-------|
| TimeTracker lines | 485 | ~320 |
| Service test files | 0 | 2 |
| Callback properties | 5 | 0 |
| Silent `try?` | 5+ | 0 |

### Files Changed

**New Files:**
- `Sources/ChronicleFeature/Services/PomodoroTimer.swift`
- `Sources/ChronicleFeature/Errors/TrackingError.swift`
- `Tests/ChronicleFeatureTests/PomodoroTimerTests.swift`
- `Tests/ChronicleFeatureTests/TimeTrackerTests.swift`

**Modified Files:**
- `TimeTracker.swift` - Extract pomodoro, add error handling
- `LocationService.swift` - Remove callback properties
- `GeofenceManager.swift` - Use protocol instead of callbacks

---

## What We Deliberately Avoided

| Pattern | Why Not |
|---------|---------|
| Event Bus | SwiftUI's `@Observable` already provides reactivity; adding an event bus duplicates this |
| Full Repository Pattern | SwiftData + `@Query` works well; repositories would add indirection without improving testability significantly |
| DI Container | `@Environment` is already DI; a container adds ceremony without benefit at this scale |
| Characterization Tests | Testing widget sync and GPS requires complex mocking; focus on what's testable |

These patterns have their place in larger codebases, but for Chronicle's size (~500 lines of service code), they add more complexity than they solve.
