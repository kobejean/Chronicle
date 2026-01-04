import SwiftUI
import SwiftData
import Observation
import UserNotifications
import CoreLocation
import OSLog

private let logger = Logger(subsystem: "Chronicle", category: "TimeTracker")

/// Central time tracking state manager
@Observable
@MainActor
public final class TimeTracker: TaskController {
    /// Currently running time entry
    public var activeEntry: TimeEntry?

    /// Last error that occurred during tracking operations
    public private(set) var lastError: TrackingError?

    // MARK: - Pomodoro (delegated to PomodoroTimer)

    private let pomodoroTimer: PomodoroTimer

    /// Pomodoro state
    public var pomodoroState: PomodoroState { pomodoroTimer.state }

    /// When the current pomodoro phase ends
    public var pomodoroPhaseEndTime: Date? { pomodoroTimer.phaseEndTime }

    /// Remaining time in current pomodoro phase
    public var pomodoroTimeRemaining: TimeInterval { pomodoroTimer.timeRemaining }

    /// Progress of current pomodoro phase (0.0 to 1.0)
    public var pomodoroProgress: Double { pomodoroTimer.progress }

    /// Whether the current pomodoro phase is paused (waiting to start)
    public var isPomodoroPhaseWaiting: Bool { pomodoroTimer.isWaiting }

    // MARK: - Location Tracking

    /// Whether GPS trail recording is enabled for time entries
    public var isGPSTrailEnabled: Bool = false

    /// Reference to location service for GPS trail recording
    private weak var locationService: LocationService?

    /// Model context for GPS point insertion
    private var gpsModelContext: ModelContext?

    // MARK: - Initialization

    public init(pomodoroTimer: PomodoroTimer = PomodoroTimer()) {
        self.pomodoroTimer = pomodoroTimer
        Task {
            await requestNotificationPermission()
        }
    }

    private func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Failed to request notification permission: \(error)")
        }
    }

    // MARK: - Location Configuration

    /// Configure location tracking dependencies
    public func configureLocation(
        service: LocationService,
        context: ModelContext
    ) {
        self.locationService = service
        self.gpsModelContext = context

        // Set up location update callback for GPS trail
        service.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.handleLocationUpdate(location)
            }
        }
    }

    /// Handle incoming location update - add GPS point to active entry
    private func handleLocationUpdate(_ location: CLLocation) {
        guard isGPSTrailEnabled,
              let entry = activeEntry,
              let context = gpsModelContext else {
            return
        }

        // Filter out inaccurate readings
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy < 100 else {
            return
        }

        let point = GPSPoint(from: location)
        point.timeEntry = entry
        context.insert(point)

        // Append to the trail
        if entry.gpsTrail == nil {
            entry.gpsTrail = []
        }
        entry.gpsTrail?.append(point)

        saveContext(context, operation: "GPS point recording")
    }

    // MARK: - Task Tracking

    /// Start a task by its ID (used by geofence triggers)
    public func startTaskByID(_ taskID: UUID, in context: ModelContext) {
        let descriptor = FetchDescriptor<TrackedTask>(
            predicate: #Predicate { $0.id == taskID }
        )

        do {
            let tasks = try context.fetch(descriptor)
            guard let task = tasks.first else {
                logger.warning("Task not found: \(taskID)")
                lastError = .taskNotFound(id: taskID)
                return
            }
            startTask(task, in: context)
        } catch {
            logger.error("Failed to fetch task \(taskID): \(error.localizedDescription)")
            lastError = .saveFailed(underlying: error)
        }
    }

    /// Start tracking a task
    public func startTask(_ task: TrackedTask, in context: ModelContext) {
        // Stop any currently running entry first
        stopCurrentEntry(in: context)

        // Create new entry
        let startTime = Date()
        let entry = TimeEntry(task: task, startTime: startTime)
        context.insert(entry)
        activeEntry = entry

        // Sync to widgets
        WidgetDataProvider.shared.setActiveTask(
            id: task.id.uuidString,
            name: task.name,
            colorHex: task.colorHex,
            startTime: startTime
        )

        // Start pomodoro if enabled
        if let settings = task.pomodoroSettings, settings.isEnabled {
            pomodoroTimer.start(with: settings)
        }

        // Start GPS tracking if enabled
        if isGPSTrailEnabled {
            locationService?.startTracking()
        }

        saveContext(context, operation: "start task")
    }

    /// Stop the current time entry
    public func stopCurrentEntry(in context: ModelContext) {
        guard let entry = activeEntry else { return }
        entry.stop()
        activeEntry = nil

        // Stop pomodoro
        pomodoroTimer.stop()

        // Stop GPS tracking
        locationService?.stopTracking()

        // Sync to widgets
        WidgetDataProvider.shared.clearActiveTask()

        saveContext(context, operation: "stop task")
    }

    /// Switch to a different task
    public func switchTask(to task: TrackedTask, in context: ModelContext) {
        stopCurrentEntry(in: context)
        startTask(task, in: context)
    }

    /// Check if a specific task is currently being tracked
    public func isTracking(_ task: TrackedTask) -> Bool {
        activeEntry?.task?.id == task.id
    }

    // MARK: - Pomodoro Controls

    /// Skip to the next pomodoro phase
    public func skipPomodoroPhase() {
        pomodoroTimer.skip()
    }

    /// Manually start the next phase (when auto-start is off)
    public func startNextPomodoroPhase() {
        pomodoroTimer.resume()
    }

    /// Reset pomodoro to the beginning
    public func resetPomodoro() {
        pomodoroTimer.reset()
    }

    // MARK: - App Lifecycle

    /// Load active entry from database on app launch
    public func loadActiveEntry(from context: ModelContext) {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            let entries = try context.fetch(descriptor)
            if let running = entries.first {
                activeEntry = running

                // Sync to widgets
                if let task = running.task {
                    WidgetDataProvider.shared.setActiveTask(
                        id: task.id.uuidString,
                        name: task.name,
                        colorHex: task.colorHex,
                        startTime: running.startTime
                    )
                }

                // Restore pomodoro state if applicable
                if let task = running.task,
                   let settings = task.pomodoroSettings,
                   settings.isEnabled {
                    // Note: We can't fully restore pomodoro progress across app restart
                    // Start a fresh work session
                    pomodoroTimer.start(with: settings)
                }
            } else {
                // No active entry - ensure widgets are cleared
                WidgetDataProvider.shared.clearActiveTask()
            }
        } catch {
            logger.error("Failed to load active entry: \(error.localizedDescription)")
            lastError = .saveFailed(underlying: error)
            WidgetDataProvider.shared.clearActiveTask()
        }
    }

    /// Sync favorite tasks to widgets
    public func syncFavoriteTasks(from context: ModelContext) {
        let descriptor = FetchDescriptor<TrackedTask>(
            predicate: #Predicate { $0.isFavorite && !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        do {
            let tasks = try context.fetch(descriptor)
            let widgetTasks = tasks.prefix(4).map { task in
                (id: task.id.uuidString, name: task.name, colorHex: task.colorHex)
            }
            WidgetDataProvider.shared.setFavoriteTasks(Array(widgetTasks))
        } catch {
            logger.error("Failed to sync favorite tasks: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Save context with error handling
    private func saveContext(_ context: ModelContext, operation: String) {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save during \(operation): \(error.localizedDescription)")
            lastError = .saveFailed(underlying: error)
        }
    }
}
