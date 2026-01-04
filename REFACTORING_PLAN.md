# Chronicle Architecture Refactoring Plan

## Overview

This document outlines a **Test-Driven Development (TDD)** approach to incrementally refactor the Chronicle codebase for improved testability, decoupling, and maintainability.

### Guiding Principles

1. **Red-Green-Refactor**: Write failing tests first, implement to pass, then refactor
2. **Small Increments**: Each change should be deployable and not break existing functionality
3. **Characterization Tests First**: Document existing behavior before changing it
4. **One Responsibility at a Time**: Extract one concern per phase

### Current Pain Points

| Issue | Location | Impact |
|-------|----------|--------|
| Monolithic TimeTracker | `TimeTracker.swift` (485 lines) | Hard to test, multiple responsibilities |
| Callback coupling | Services use closure callbacks | Circular dependencies, untestable |
| Direct SwiftData access | All services | Cannot mock data layer |
| Silent error handling | `try? context.save()` | Bugs go unnoticed |
| No service tests | `Tests/` directory | Only models tested |

---

## Phase 1: Characterization Tests for Existing Behavior

**Goal**: Document current behavior with tests before any refactoring

### 1.1 TimeTracker Characterization Tests

Create tests that capture the current behavior of TimeTracker without modifying it.

```
Tests/ChronicleFeatureTests/
└── Services/
    └── TimeTrackerCharacterizationTests.swift
```

#### Test Cases to Write

- [ ] **Active Entry State**
  - `activeEntry` is nil when no task is running
  - `activeEntry` is set after starting a task
  - `activeEntry` is nil after stopping

- [ ] **Task Tracking**
  - `isTracking(_:)` returns true for active task
  - `isTracking(_:)` returns false for inactive task
  - Starting a new task stops the previous one

- [ ] **Pomodoro State**
  - `pomodoroState` is `.idle` by default
  - `pomodoroState` changes to `.working` when task with pomodoro starts
  - `pomodoroTimeRemaining` decreases over time
  - `pomodoroProgress` increases from 0 to 1

- [ ] **Widget Sync**
  - Starting a task updates widget data
  - Stopping a task clears widget data

#### Implementation Notes

These tests will require a real `ModelContext` since we can't mock it yet. Use in-memory SwiftData container:

```swift
@Suite("TimeTracker Characterization Tests")
@MainActor
struct TimeTrackerCharacterizationTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: TrackedTask.self, TimeEntry.self, PomodoroSettings.self,
            configurations: config
        )
    }

    @Test("activeEntry is nil initially")
    func activeEntryInitiallyNil() async throws {
        let tracker = TimeTracker()
        #expect(tracker.activeEntry == nil)
    }

    // ... more tests
}
```

### 1.2 PomodoroState Unit Tests

Expand existing `PomodoroTests.swift` with edge cases:

- [ ] State equality with different total sessions
- [ ] Phase transitions (working → break → working)
- [ ] Timer calculations at boundaries

### 1.3 Acceptance Criteria

- [ ] All characterization tests pass with current implementation
- [ ] Tests document expected behavior clearly
- [ ] No production code changes in this phase

---

## Phase 2: Extract PomodoroTimer Service

**Goal**: Extract pomodoro logic into a dedicated, testable service

### 2.1 Define PomodoroTimer Protocol (TDD Red Phase)

Write tests for the interface we want:

```swift
// Tests/ChronicleFeatureTests/Services/PomodoroTimerTests.swift

@Suite("PomodoroTimer Tests")
@MainActor
struct PomodoroTimerTests {

    @Test("Initial state is idle")
    func initialStateIsIdle() {
        let timer = PomodoroTimer()
        #expect(timer.state == .idle)
        #expect(timer.phaseEndTime == nil)
    }

    @Test("Starting with settings begins work phase")
    func startBeginsWorkPhase() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.workDuration = 25
        settings.sessionsBeforeLongBreak = 4

        timer.start(with: settings)

        #expect(timer.state == .working(sessionNumber: 1, totalSessions: 4))
        #expect(timer.phaseEndTime != nil)
    }

    @Test("Stop resets to idle")
    func stopResetsToIdle() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true

        timer.start(with: settings)
        timer.stop()

        #expect(timer.state == .idle)
        #expect(timer.phaseEndTime == nil)
    }

    @Test("Skip advances to next phase")
    func skipAdvancesToNextPhase() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4

        timer.start(with: settings)
        #expect(timer.state == .working(sessionNumber: 1, totalSessions: 4))

        timer.skip()

        // After work comes short break
        #expect(timer.state == .shortBreak(afterSession: 1))
    }

    @Test("Time remaining decreases")
    func timeRemainingDecreases() async throws {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.workDuration = 1 // 1 minute for faster test

        timer.start(with: settings)
        let initialRemaining = timer.timeRemaining

        try await Task.sleep(for: .milliseconds(100))

        #expect(timer.timeRemaining < initialRemaining)
    }

    @Test("Progress increases over time")
    func progressIncreases() async throws {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.workDuration = 1

        timer.start(with: settings)
        let initialProgress = timer.progress

        try await Task.sleep(for: .milliseconds(100))

        #expect(timer.progress > initialProgress)
    }

    @Test("Phase completion transitions automatically")
    func phaseCompletionTransitions() async throws {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.workDuration = 1 // 1 minute
        settings.autoStartBreaks = true

        // Use a very short duration for testing
        timer.start(with: settings, workDurationOverride: 0.1) // 0.1 seconds

        try await Task.sleep(for: .milliseconds(200))

        // Should have transitioned to break
        if case .shortBreak = timer.state {
            // Expected
        } else {
            Issue.record("Expected shortBreak state, got \(timer.state)")
        }
    }
}
```

### 2.2 Implement PomodoroTimer (TDD Green Phase)

Create the new service to make tests pass:

```swift
// Sources/ChronicleFeature/Services/PomodoroTimer.swift

import SwiftUI
import Observation
import AudioToolbox
import UserNotifications

/// Dedicated pomodoro timer service
@Observable
@MainActor
public final class PomodoroTimer {

    // MARK: - Public State

    public private(set) var state: PomodoroState = .idle
    public private(set) var phaseEndTime: Date?
    public private(set) var settings: PomodoroSettings?

    // MARK: - Computed Properties

    public var timeRemaining: TimeInterval {
        guard let endTime = phaseEndTime else { return 0 }
        return max(0, endTime.timeIntervalSinceNow)
    }

    public var progress: Double {
        guard let settings, phaseEndTime != nil else { return 0 }

        let totalDuration: TimeInterval
        switch state {
        case .working:
            totalDuration = settings.workTimeInterval
        case .shortBreak:
            totalDuration = settings.shortBreakTimeInterval
        case .longBreak:
            totalDuration = settings.longBreakTimeInterval
        case .idle:
            return 0
        }

        let elapsed = totalDuration - timeRemaining
        return min(1.0, max(0.0, elapsed / totalDuration))
    }

    public var isWaiting: Bool {
        state.isActive && phaseEndTime == nil
    }

    // MARK: - Private

    private var timer: Timer?

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Public Methods

    public func start(with settings: PomodoroSettings, workDurationOverride: TimeInterval? = nil) {
        self.settings = settings
        startPhase(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak),
                   durationOverride: workDurationOverride)
    }

    public func stop() {
        state = .idle
        phaseEndTime = nil
        settings = nil
        stopTimer()
        cancelNotifications()
    }

    public func skip() {
        transitionToNextPhase()
    }

    public func resume() {
        guard isWaiting else { return }

        switch state {
        case .working(let session, let total):
            startPhase(.working(sessionNumber: session, totalSessions: total))
        case .shortBreak(let after):
            startPhase(.shortBreak(afterSession: after))
        case .longBreak:
            startPhase(.longBreak)
        case .idle:
            break
        }
    }

    public func reset() {
        guard let settings else { return }
        startPhase(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak))
    }

    // MARK: - Private Methods

    private func startPhase(_ newState: PomodoroState, durationOverride: TimeInterval? = nil) {
        guard let settings else { return }

        state = newState

        let duration: TimeInterval
        switch newState {
        case .working:
            duration = durationOverride ?? settings.workTimeInterval
        case .shortBreak:
            duration = durationOverride ?? settings.shortBreakTimeInterval
        case .longBreak:
            duration = durationOverride ?? settings.longBreakTimeInterval
        case .idle:
            phaseEndTime = nil
            stopTimer()
            return
        }

        phaseEndTime = Date().addingTimeInterval(duration)
        startTimer()
        scheduleNotification(for: newState, in: duration)
    }

    private func transitionToNextPhase() {
        guard let settings else { return }

        playCompletionFeedback()

        switch state {
        case .working(let session, let total):
            if session >= total {
                // Long break after all sessions
                if settings.autoStartBreaks {
                    startPhase(.longBreak)
                } else {
                    state = .longBreak
                    phaseEndTime = nil
                    stopTimer()
                }
            } else {
                // Short break
                if settings.autoStartBreaks {
                    startPhase(.shortBreak(afterSession: session))
                } else {
                    state = .shortBreak(afterSession: session)
                    phaseEndTime = nil
                    stopTimer()
                }
            }

        case .shortBreak(let afterSession):
            let nextSession = afterSession + 1
            if settings.autoStartWork {
                startPhase(.working(sessionNumber: nextSession, totalSessions: settings.sessionsBeforeLongBreak))
            } else {
                state = .working(sessionNumber: nextSession, totalSessions: settings.sessionsBeforeLongBreak)
                phaseEndTime = nil
                stopTimer()
            }

        case .longBreak:
            if settings.autoStartWork {
                startPhase(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak))
            } else {
                state = .working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak)
                phaseEndTime = nil
                stopTimer()
            }

        case .idle:
            break
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPhaseCompletion()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPhaseCompletion() {
        guard phaseEndTime != nil, timeRemaining <= 0 else { return }
        transitionToNextPhase()
    }

    private func playCompletionFeedback() {
        AudioServicesPlaySystemSound(1007)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func scheduleNotification(for state: PomodoroState, in duration: TimeInterval) {
        let content = UNMutableNotificationContent()

        switch state {
        case .working:
            content.title = "Work Session Complete!"
            content.body = "Time for a break. Great work!"
        case .shortBreak:
            content.title = "Break Over"
            content.body = "Ready to get back to work?"
        case .longBreak:
            content.title = "Long Break Over"
            content.body = "Feeling refreshed? Let's continue!"
        case .idle:
            return
        }

        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pomodoro-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - PomodoroState (moved from TimeTracker)

public enum PomodoroState: Equatable, Sendable {
    case idle
    case working(sessionNumber: Int, totalSessions: Int)
    case shortBreak(afterSession: Int)
    case longBreak

    public var isActive: Bool {
        self != .idle
    }

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .working: return "Working"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    public var phaseColor: Color {
        switch self {
        case .idle: return .secondary
        case .working: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}
```

### 2.3 Integrate PomodoroTimer into TimeTracker (TDD Refactor Phase)

Update TimeTracker to delegate to PomodoroTimer:

```swift
// Simplified TimeTracker after extraction

@Observable
@MainActor
public final class TimeTracker {
    public var activeEntry: TimeEntry?

    // Delegate to PomodoroTimer
    private let pomodoroTimer: PomodoroTimer

    // Expose pomodoro state through computed properties
    public var pomodoroState: PomodoroState { pomodoroTimer.state }
    public var pomodoroPhaseEndTime: Date? { pomodoroTimer.phaseEndTime }
    public var pomodoroTimeRemaining: TimeInterval { pomodoroTimer.timeRemaining }
    public var pomodoroProgress: Double { pomodoroTimer.progress }
    public var isPomodoroPhaseWaiting: Bool { pomodoroTimer.isWaiting }

    public init(pomodoroTimer: PomodoroTimer = PomodoroTimer()) {
        self.pomodoroTimer = pomodoroTimer
    }

    public func startTask(_ task: TrackedTask, in context: ModelContext) {
        stopCurrentEntry(in: context)

        let entry = TimeEntry(task: task, startTime: Date())
        context.insert(entry)
        activeEntry = entry

        // Delegate pomodoro to dedicated service
        if let settings = task.pomodoroSettings, settings.isEnabled {
            pomodoroTimer.start(with: settings)
        }

        // ... rest of implementation
    }

    public func stopCurrentEntry(in context: ModelContext) {
        guard let entry = activeEntry else { return }
        entry.stop()
        activeEntry = nil
        pomodoroTimer.stop()
        // ... rest of implementation
    }

    // Pomodoro controls delegate to timer
    public func skipPomodoroPhase() { pomodoroTimer.skip() }
    public func startNextPomodoroPhase() { pomodoroTimer.resume() }
    public func resetPomodoro() { pomodoroTimer.reset() }
}
```

### 2.4 Acceptance Criteria

- [ ] All PomodoroTimer tests pass
- [ ] All existing characterization tests still pass
- [ ] TimeTracker reduced by ~150 lines
- [ ] PomodoroTimer is independently testable
- [ ] App functionality unchanged

---

## Phase 3: Implement Event Bus Pattern

**Goal**: Decouple services using event-driven communication

### 3.1 Define Events and EventBus (TDD Red Phase)

```swift
// Tests/ChronicleFeatureTests/Events/EventBusTests.swift

@Suite("EventBus Tests")
@MainActor
struct EventBusTests {

    @Test("Publishing event updates stream")
    func publishUpdatesStream() async {
        let bus = EventBus()

        var receivedEvents: [TrackingEvent] = []
        let task = Task {
            for await event in bus.events {
                receivedEvents.append(event)
                if receivedEvents.count >= 2 { break }
            }
        }

        bus.publish(.taskStarted(taskID: UUID()))
        bus.publish(.taskStopped)

        await task.value

        #expect(receivedEvents.count == 2)
    }

    @Test("Multiple subscribers receive events")
    func multipleSubscribers() async {
        let bus = EventBus()

        var subscriber1Events: [TrackingEvent] = []
        var subscriber2Events: [TrackingEvent] = []

        let task1 = Task {
            for await event in bus.events {
                subscriber1Events.append(event)
                break
            }
        }

        let task2 = Task {
            for await event in bus.events {
                subscriber2Events.append(event)
                break
            }
        }

        // Give subscribers time to start
        try? await Task.sleep(for: .milliseconds(10))

        bus.publish(.taskStopped)

        await task1.value
        await task2.value

        #expect(subscriber1Events.count == 1)
        #expect(subscriber2Events.count == 1)
    }
}
```

### 3.2 Implement EventBus (TDD Green Phase)

```swift
// Sources/ChronicleFeature/Events/TrackingEvent.swift

import Foundation
import CoreLocation

/// Events that can be published across services
public enum TrackingEvent: Sendable {
    // Time tracking events
    case taskStarted(taskID: UUID, taskName: String)
    case taskStopped(entryID: UUID)
    case taskSwitched(fromTaskID: UUID?, toTaskID: UUID)

    // Location events
    case locationUpdated(latitude: Double, longitude: Double, accuracy: Double)
    case geofenceEntered(placeID: UUID, placeName: String)
    case geofenceExited(placeID: UUID, placeName: String)

    // Pomodoro events
    case pomodoroPhaseStarted(PomodoroState)
    case pomodoroPhaseCompleted(PomodoroState)
    case pomodoroStopped

    // Widget events
    case widgetSyncRequested
}
```

```swift
// Sources/ChronicleFeature/Events/EventBus.swift

import Foundation

/// Central event bus for decoupled service communication
@MainActor
public final class EventBus: @unchecked Sendable {

    private let continuation: AsyncStream<TrackingEvent>.Continuation
    public let events: AsyncStream<TrackingEvent>

    public init() {
        var continuation: AsyncStream<TrackingEvent>.Continuation!
        events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    public func publish(_ event: TrackingEvent) {
        continuation.yield(event)
    }

    deinit {
        continuation.finish()
    }
}
```

### 3.3 Migrate LocationService to EventBus

```swift
// Updated LocationService using EventBus

@Observable
@MainActor
public final class LocationService: NSObject, Sendable {
    // Remove callback properties
    // public var onLocationUpdate: ((CLLocation) -> Void)?  // REMOVED
    // public var onGeofenceEnter: ((String) -> Void)?       // REMOVED
    // public var onGeofenceExit: ((String) -> Void)?        // REMOVED

    private let eventBus: EventBus

    public init(eventBus: EventBus) {
        self.eventBus = eventBus
        super.init()
        // ... rest of init
    }

    // In delegate methods, publish events instead of calling callbacks
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            currentLocation = location
            eventBus.publish(.locationUpdated(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy
            ))
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            eventBus.publish(.geofenceEntered(
                placeID: UUID(uuidString: region.identifier) ?? UUID(),
                placeName: region.identifier
            ))
        }
    }
}
```

### 3.4 Acceptance Criteria

- [ ] EventBus tests pass
- [ ] LocationService uses EventBus instead of callbacks
- [ ] GeofenceManager subscribes to EventBus
- [ ] TimeTracker subscribes to EventBus
- [ ] No more closure-based coupling between services
- [ ] All characterization tests still pass

---

## Phase 4: Add Repository Pattern

**Goal**: Abstract data access for testability

### 4.1 Define Repository Protocols (TDD Red Phase)

```swift
// Tests/ChronicleFeatureTests/Repositories/TaskRepositoryTests.swift

@Suite("TaskRepository Tests")
@MainActor
struct TaskRepositoryTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: TrackedTask.self, TimeEntry.self, configurations: config)
    }

    @Test("Fetch by ID returns correct task")
    func fetchByID() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TaskRepository(context: context)

        let task = TrackedTask(name: "Test Task")
        context.insert(task)
        try context.save()

        let fetched = try await repo.fetch(id: task.id)

        #expect(fetched?.id == task.id)
        #expect(fetched?.name == "Test Task")
    }

    @Test("Fetch by ID returns nil for unknown ID")
    func fetchByIDUnknown() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TaskRepository(context: context)

        let fetched = try await repo.fetch(id: UUID())

        #expect(fetched == nil)
    }

    @Test("Fetch favorites returns only favorited tasks")
    func fetchFavorites() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TaskRepository(context: context)

        let task1 = TrackedTask(name: "Favorite")
        task1.isFavorite = true
        let task2 = TrackedTask(name: "Not Favorite")
        task2.isFavorite = false

        context.insert(task1)
        context.insert(task2)
        try context.save()

        let favorites = try await repo.fetchFavorites()

        #expect(favorites.count == 1)
        #expect(favorites.first?.name == "Favorite")
    }

    @Test("Fetch active tasks excludes archived")
    func fetchActiveExcludesArchived() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TaskRepository(context: context)

        let active = TrackedTask(name: "Active")
        let archived = TrackedTask(name: "Archived")
        archived.isArchived = true

        context.insert(active)
        context.insert(archived)
        try context.save()

        let tasks = try await repo.fetchActive()

        #expect(tasks.count == 1)
        #expect(tasks.first?.name == "Active")
    }
}
```

### 4.2 Implement Repository (TDD Green Phase)

```swift
// Sources/ChronicleFeature/Repositories/TaskRepository.swift

import Foundation
import SwiftData

/// Protocol for task data access
public protocol TaskRepositoryProtocol: Sendable {
    func fetch(id: UUID) async throws -> TrackedTask?
    func fetchAll() async throws -> [TrackedTask]
    func fetchActive() async throws -> [TrackedTask]
    func fetchFavorites() async throws -> [TrackedTask]
    func save() async throws
}

/// SwiftData implementation of TaskRepository
@MainActor
public final class TaskRepository: TaskRepositoryProtocol {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetch(id: UUID) async throws -> TrackedTask? {
        let descriptor = FetchDescriptor<TrackedTask>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    public func fetchAll() async throws -> [TrackedTask] {
        let descriptor = FetchDescriptor<TrackedTask>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(descriptor)
    }

    public func fetchActive() async throws -> [TrackedTask] {
        let descriptor = FetchDescriptor<TrackedTask>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(descriptor)
    }

    public func fetchFavorites() async throws -> [TrackedTask] {
        let descriptor = FetchDescriptor<TrackedTask>(
            predicate: #Predicate { $0.isFavorite && !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(descriptor)
    }

    public func save() async throws {
        try context.save()
    }
}

/// Mock implementation for testing
public final class MockTaskRepository: TaskRepositoryProtocol, @unchecked Sendable {
    public var tasks: [TrackedTask] = []
    public var saveCallCount = 0
    public var shouldThrowOnSave = false

    public init() {}

    public func fetch(id: UUID) async throws -> TrackedTask? {
        tasks.first { $0.id == id }
    }

    public func fetchAll() async throws -> [TrackedTask] {
        tasks
    }

    public func fetchActive() async throws -> [TrackedTask] {
        tasks.filter { !$0.isArchived }
    }

    public func fetchFavorites() async throws -> [TrackedTask] {
        tasks.filter { $0.isFavorite && !$0.isArchived }
    }

    public func save() async throws {
        if shouldThrowOnSave {
            throw RepositoryError.saveFailed
        }
        saveCallCount += 1
    }
}

public enum RepositoryError: Error {
    case saveFailed
    case notFound
}
```

### 4.3 Additional Repositories

Create similar repositories for:

- [ ] `TimeEntryRepository` - fetch running entry, entries by date range
- [ ] `PlaceRepository` - fetch places with geofencing enabled
- [ ] `GoalRepository` - fetch goals by task

### 4.4 Acceptance Criteria

- [ ] All repository tests pass
- [ ] Mock repositories enable service unit testing
- [ ] Services use repository protocols, not direct SwiftData
- [ ] Error handling improved (no more `try?`)

---

## Phase 5: Service Container & Dependency Injection

**Goal**: Centralize service creation and wiring

### 5.1 Define ServiceContainer (TDD Red Phase)

```swift
// Tests/ChronicleFeatureTests/DI/ServiceContainerTests.swift

@Suite("ServiceContainer Tests")
@MainActor
struct ServiceContainerTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: TrackedTask.self, TimeEntry.self, Place.self,
            configurations: config
        )
    }

    @Test("All services are initialized")
    func allServicesInitialized() throws {
        let modelContainer = try makeContainer()
        let container = ServiceContainer(modelContext: modelContainer.mainContext)

        #expect(container.timeTracker != nil)
        #expect(container.pomodoroTimer != nil)
        #expect(container.locationService != nil)
        #expect(container.geofenceManager != nil)
        #expect(container.eventBus != nil)
    }

    @Test("Services share the same EventBus")
    func servicesShareEventBus() throws {
        let modelContainer = try makeContainer()
        let container = ServiceContainer(modelContext: modelContainer.mainContext)

        // All services should use the same event bus
        // (This would require exposing eventBus on services for testing)
    }
}
```

### 5.2 Implement ServiceContainer (TDD Green Phase)

```swift
// Sources/ChronicleFeature/DI/ServiceContainer.swift

import Foundation
import SwiftData

/// Central container for all app services
@MainActor
public final class ServiceContainer: Observable {

    // MARK: - Services

    public let eventBus: EventBus
    public let pomodoroTimer: PomodoroTimer
    public let locationService: LocationService
    public let geofenceManager: GeofenceManager
    public let timeTracker: TimeTracker

    // MARK: - Repositories

    public let taskRepository: TaskRepository
    public let timeEntryRepository: TimeEntryRepository
    public let placeRepository: PlaceRepository

    // MARK: - Initialization

    public init(modelContext: ModelContext) {
        // Create shared event bus
        let eventBus = EventBus()
        self.eventBus = eventBus

        // Create repositories
        self.taskRepository = TaskRepository(context: modelContext)
        self.timeEntryRepository = TimeEntryRepository(context: modelContext)
        self.placeRepository = PlaceRepository(context: modelContext)

        // Create services with dependencies
        self.pomodoroTimer = PomodoroTimer(eventBus: eventBus)
        self.locationService = LocationService(eventBus: eventBus)
        self.geofenceManager = GeofenceManager(
            locationService: locationService,
            placeRepository: placeRepository,
            eventBus: eventBus
        )
        self.timeTracker = TimeTracker(
            pomodoroTimer: pomodoroTimer,
            taskRepository: taskRepository,
            timeEntryRepository: timeEntryRepository,
            eventBus: eventBus
        )

        // Start event subscriptions
        setupEventSubscriptions()
    }

    private func setupEventSubscriptions() {
        // TimeTracker listens for geofence events
        Task {
            for await event in eventBus.events {
                switch event {
                case .geofenceEntered(let placeID, _):
                    await handleGeofenceEnter(placeID: placeID)
                case .geofenceExited(let placeID, _):
                    await handleGeofenceExit(placeID: placeID)
                default:
                    break
                }
            }
        }
    }

    private func handleGeofenceEnter(placeID: UUID) async {
        // Delegate to geofence manager which will publish taskStarted event
    }

    private func handleGeofenceExit(placeID: UUID) async {
        // Delegate to geofence manager which will publish taskStopped event
    }
}
```

### 5.3 Update ContentView

```swift
// Updated ContentView using ServiceContainer

public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var services: ServiceContainer?
    @State private var selectedTab = 0

    public var body: some View {
        Group {
            if let services {
                TabView(selection: $selectedTab) {
                    TimerHomeView()
                        .tabItem { Label("Timer", systemImage: "timer") }
                        .tag(0)

                    // ... other tabs
                }
                .environment(services.timeTracker)
                .environment(services.pomodoroTimer)
                .environment(services.locationService)
                .environment(services.geofenceManager)
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            services = ServiceContainer(modelContext: modelContext)
        }
    }
}
```

### 5.4 Acceptance Criteria

- [ ] ServiceContainer tests pass
- [ ] All services created through container
- [ ] Dependencies properly injected
- [ ] ContentView simplified
- [ ] Easy to create test containers with mocks

---

## Phase 6: Integration Tests

**Goal**: Verify services work together correctly

### 6.1 Service Integration Tests

```swift
// Tests/ChronicleFeatureTests/Integration/TimeTrackingIntegrationTests.swift

@Suite("Time Tracking Integration Tests")
@MainActor
struct TimeTrackingIntegrationTests {

    private func makeContainer() throws -> (ServiceContainer, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(
            for: TrackedTask.self, TimeEntry.self, Place.self, PomodoroSettings.self,
            configurations: config
        )
        let services = ServiceContainer(modelContext: modelContainer.mainContext)
        return (services, modelContainer)
    }

    @Test("Starting task with pomodoro activates timer")
    func startTaskWithPomodoro() async throws {
        let (services, modelContainer) = try makeContainer()
        let context = modelContainer.mainContext

        // Create task with pomodoro
        let task = TrackedTask(name: "Focus Work")
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.workDuration = 25
        task.pomodoroSettings = settings
        context.insert(task)
        try context.save()

        // Start the task
        services.timeTracker.startTask(task)

        // Verify both tracker and pomodoro are active
        #expect(services.timeTracker.activeEntry != nil)
        #expect(services.pomodoroTimer.state != .idle)
        #expect(services.pomodoroTimer.phaseEndTime != nil)
    }

    @Test("Stopping task stops pomodoro")
    func stopTaskStopsPomodoro() async throws {
        let (services, modelContainer) = try makeContainer()
        let context = modelContainer.mainContext

        let task = TrackedTask(name: "Focus Work")
        let settings = PomodoroSettings()
        settings.isEnabled = true
        task.pomodoroSettings = settings
        context.insert(task)

        services.timeTracker.startTask(task)
        services.timeTracker.stopCurrentEntry()

        #expect(services.timeTracker.activeEntry == nil)
        #expect(services.pomodoroTimer.state == .idle)
    }

    @Test("Event bus connects location and tracker")
    func eventBusConnectsServices() async throws {
        let (services, _) = try makeContainer()

        var receivedEvents: [TrackingEvent] = []

        Task {
            for await event in services.eventBus.events {
                receivedEvents.append(event)
                if receivedEvents.count >= 1 { break }
            }
        }

        // Simulate location update (if we had a way to trigger it)
        // This would test the full event flow
    }
}
```

### 6.2 Acceptance Criteria

- [ ] Integration tests verify service interactions
- [ ] Event flow tested end-to-end
- [ ] Data persistence verified across operations
- [ ] Edge cases covered (concurrent operations, error recovery)

---

## Implementation Timeline

### Sprint 1: Foundation
- [ ] Phase 1: Characterization tests (2-3 days)
- [ ] Phase 2.1-2.2: PomodoroTimer extraction (2-3 days)

### Sprint 2: Decoupling
- [ ] Phase 2.3-2.4: Integrate PomodoroTimer (1-2 days)
- [ ] Phase 3: EventBus implementation (3-4 days)

### Sprint 3: Data Layer
- [ ] Phase 4: Repository pattern (3-4 days)
- [ ] Phase 5: ServiceContainer (2-3 days)

### Sprint 4: Verification
- [ ] Phase 6: Integration tests (2-3 days)
- [ ] Final cleanup and documentation (1-2 days)

---

## Success Metrics

| Metric | Before | Target |
|--------|--------|--------|
| TimeTracker lines | 485 | <300 |
| Service test coverage | 0% | >80% |
| Callback dependencies | 5+ | 0 |
| Direct SwiftData queries in services | 10+ | 0 |
| Test files | 7 | 12+ |

---

## Risk Mitigation

1. **Breaking Changes**: Run all tests after each commit
2. **Regression**: Keep characterization tests passing throughout
3. **Over-engineering**: Only implement what's needed for testability
4. **Timeline Slip**: Each phase is independently valuable; can stop after any phase

---

## Appendix: File Changes Summary

### New Files to Create

```
Sources/ChronicleFeature/
├── Services/
│   └── PomodoroTimer.swift          # Phase 2
├── Events/
│   ├── TrackingEvent.swift          # Phase 3
│   └── EventBus.swift               # Phase 3
├── Repositories/
│   ├── TaskRepository.swift         # Phase 4
│   ├── TimeEntryRepository.swift    # Phase 4
│   └── PlaceRepository.swift        # Phase 4
└── DI/
    └── ServiceContainer.swift       # Phase 5

Tests/ChronicleFeatureTests/
├── Services/
│   ├── TimeTrackerCharacterizationTests.swift  # Phase 1
│   └── PomodoroTimerTests.swift                # Phase 2
├── Events/
│   └── EventBusTests.swift                     # Phase 3
├── Repositories/
│   ├── TaskRepositoryTests.swift               # Phase 4
│   ├── TimeEntryRepositoryTests.swift          # Phase 4
│   └── PlaceRepositoryTests.swift              # Phase 4
├── DI/
│   └── ServiceContainerTests.swift             # Phase 5
└── Integration/
    └── TimeTrackingIntegrationTests.swift      # Phase 6
```

### Files to Modify

| File | Phase | Changes |
|------|-------|---------|
| `TimeTracker.swift` | 2, 3, 4 | Extract pomodoro, use EventBus, use repositories |
| `LocationService.swift` | 3 | Replace callbacks with EventBus |
| `GeofenceManager.swift` | 3, 4 | Use EventBus and PlaceRepository |
| `ContentView.swift` | 5 | Use ServiceContainer |
| `PomodoroTests.swift` | 2 | Move PomodoroState tests |

---

## Next Steps

1. Review and approve this plan
2. Create feature branch for Phase 1
3. Begin writing characterization tests
4. Proceed through phases incrementally
