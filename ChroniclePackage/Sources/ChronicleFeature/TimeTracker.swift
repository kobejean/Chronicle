import SwiftUI
import SwiftData
import Observation
import AudioToolbox
import UserNotifications
import CoreLocation

/// Central time tracking state manager
@Observable
@MainActor
public final class TimeTracker {
    /// Currently running time entry
    public var activeEntry: TimeEntry?

    /// Pomodoro state
    public var pomodoroState: PomodoroState = .idle

    /// When the current pomodoro phase ends
    public var pomodoroPhaseEndTime: Date?

    /// Current pomodoro settings (from active task)
    public var activePomodoroSettings: PomodoroSettings?

    /// Timer for checking pomodoro phase completion
    private var pomodoroTimer: Timer?

    // MARK: - Location Tracking

    /// Whether GPS trail recording is enabled for time entries
    public var isGPSTrailEnabled: Bool = false

    /// Reference to location service for GPS trail recording
    private weak var locationService: LocationService?

    /// Reference to geofence manager
    private weak var geofenceManager: GeofenceManager?

    /// Model context for GPS point insertion
    private var gpsModelContext: ModelContext?

    public enum PomodoroState: Equatable {
        case idle
        case working(sessionNumber: Int, totalSessions: Int)
        case shortBreak(afterSession: Int)
        case longBreak

        var isActive: Bool {
            self != .idle
        }

        var displayName: String {
            switch self {
            case .idle: return "Idle"
            case .working: return "Working"
            case .shortBreak: return "Short Break"
            case .longBreak: return "Long Break"
            }
        }

        var phaseColor: Color {
            switch self {
            case .idle: return .secondary
            case .working: return .red
            case .shortBreak: return .green
            case .longBreak: return .blue
            }
        }
    }

    /// Remaining time in current pomodoro phase
    public var pomodoroTimeRemaining: TimeInterval {
        guard let endTime = pomodoroPhaseEndTime else { return 0 }
        return max(0, endTime.timeIntervalSinceNow)
    }

    /// Progress of current pomodoro phase (0.0 to 1.0)
    public var pomodoroProgress: Double {
        guard let settings = activePomodoroSettings,
              pomodoroPhaseEndTime != nil else { return 0 }

        let totalDuration: TimeInterval
        switch pomodoroState {
        case .working:
            totalDuration = settings.workTimeInterval
        case .shortBreak:
            totalDuration = settings.shortBreakTimeInterval
        case .longBreak:
            totalDuration = settings.longBreakTimeInterval
        case .idle:
            return 0
        }

        let elapsed = totalDuration - pomodoroTimeRemaining
        return min(1.0, max(0.0, elapsed / totalDuration))
    }

    public init() {
        Task {
            await requestNotificationPermission()
        }
    }

    /// Configure location tracking dependencies
    public func configureLocation(
        service: LocationService,
        geofence: GeofenceManager,
        context: ModelContext
    ) {
        self.locationService = service
        self.geofenceManager = geofence
        self.gpsModelContext = context

        // Set up location update callback for GPS trail
        service.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.handleLocationUpdate(location)
            }
        }

        // Set up geofence callbacks
        geofence.onStartTask = { [weak self] taskID in
            Task { @MainActor in
                self?.startTaskByID(taskID, in: context)
            }
        }

        geofence.onStopTask = { [weak self] in
            Task { @MainActor in
                self?.stopCurrentEntry(in: context)
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

        try? context.save()
    }

    /// Start a task by its ID (used by geofence triggers)
    public func startTaskByID(_ taskID: UUID, in context: ModelContext) {
        let descriptor = FetchDescriptor<TrackedTask>(
            predicate: #Predicate { $0.id == taskID }
        )

        guard let tasks = try? context.fetch(descriptor),
              let task = tasks.first else {
            return
        }

        startTask(task, in: context)
    }

    private func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Failed to request notification permission: \(error)")
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

        // Check for pomodoro settings
        if let settings = task.pomodoroSettings, settings.isEnabled {
            activePomodoroSettings = settings
            startPomodoroPhase(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak))
        } else {
            activePomodoroSettings = nil
            pomodoroState = .idle
            pomodoroPhaseEndTime = nil
        }

        // Start GPS tracking if enabled
        if isGPSTrailEnabled {
            locationService?.startTracking()
        }

        try? context.save()
    }

    /// Start a specific pomodoro phase
    private func startPomodoroPhase(_ state: PomodoroState) {
        guard let settings = activePomodoroSettings else { return }

        pomodoroState = state

        let duration: TimeInterval
        switch state {
        case .working:
            duration = settings.workTimeInterval
        case .shortBreak:
            duration = settings.shortBreakTimeInterval
        case .longBreak:
            duration = settings.longBreakTimeInterval
        case .idle:
            pomodoroPhaseEndTime = nil
            stopPomodoroTimer()
            return
        }

        pomodoroPhaseEndTime = Date().addingTimeInterval(duration)
        startPomodoroTimer()
        scheduleNotification(for: state, in: duration)
    }

    /// Start the pomodoro timer that checks for phase completion
    private func startPomodoroTimer() {
        stopPomodoroTimer()
        pomodoroTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPomodoroPhaseCompletion()
            }
        }
    }

    /// Stop the pomodoro timer
    private func stopPomodoroTimer() {
        pomodoroTimer?.invalidate()
        pomodoroTimer = nil
    }

    /// Check if the current pomodoro phase has completed
    private func checkPomodoroPhaseCompletion() {
        guard pomodoroPhaseEndTime != nil,
              pomodoroTimeRemaining <= 0 else { return }

        transitionToNextPhase()
    }

    /// Transition to the next pomodoro phase
    private func transitionToNextPhase() {
        guard let settings = activePomodoroSettings else { return }

        // Play completion sound
        playCompletionSound()
        triggerHapticFeedback()

        switch pomodoroState {
        case .working(let session, let total):
            // Work session complete - go to break
            if session >= total {
                // Long break after completing all sessions
                if settings.autoStartBreaks {
                    startPomodoroPhase(.longBreak)
                } else {
                    pomodoroState = .longBreak
                    pomodoroPhaseEndTime = nil
                    stopPomodoroTimer()
                }
            } else {
                // Short break
                if settings.autoStartBreaks {
                    startPomodoroPhase(.shortBreak(afterSession: session))
                } else {
                    pomodoroState = .shortBreak(afterSession: session)
                    pomodoroPhaseEndTime = nil
                    stopPomodoroTimer()
                }
            }

        case .shortBreak(let afterSession):
            // Short break complete - start next work session
            let nextSession = afterSession + 1
            if let settings = activePomodoroSettings {
                if settings.autoStartWork {
                    startPomodoroPhase(.working(sessionNumber: nextSession, totalSessions: settings.sessionsBeforeLongBreak))
                } else {
                    pomodoroState = .working(sessionNumber: nextSession, totalSessions: settings.sessionsBeforeLongBreak)
                    pomodoroPhaseEndTime = nil
                    stopPomodoroTimer()
                }
            }

        case .longBreak:
            // Long break complete - reset to first session
            if let settings = activePomodoroSettings {
                if settings.autoStartWork {
                    startPomodoroPhase(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak))
                } else {
                    pomodoroState = .working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak)
                    pomodoroPhaseEndTime = nil
                    stopPomodoroTimer()
                }
            }

        case .idle:
            break
        }
    }

    /// Skip to the next pomodoro phase
    public func skipPomodoroPhase() {
        transitionToNextPhase()
    }

    /// Manually start the next phase (when auto-start is off)
    public func startNextPomodoroPhase() {
        guard pomodoroPhaseEndTime == nil else { return } // Already running

        switch pomodoroState {
        case .working(let session, let total):
            startPomodoroPhase(.working(sessionNumber: session, totalSessions: total))
        case .shortBreak(let afterSession):
            startPomodoroPhase(.shortBreak(afterSession: afterSession))
        case .longBreak:
            startPomodoroPhase(.longBreak)
        case .idle:
            break
        }
    }

    /// Reset pomodoro to the beginning
    public func resetPomodoro() {
        guard let settings = activePomodoroSettings else { return }
        startPomodoroPhase(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak))
    }

    /// Play a completion sound
    private func playCompletionSound() {
        AudioServicesPlaySystemSound(1007) // Standard notification sound
    }

    /// Trigger haptic feedback
    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Schedule a local notification for phase completion
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
        let request = UNNotificationRequest(identifier: "pomodoro-\(UUID().uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    /// Cancel all pending pomodoro notifications
    private func cancelPomodoroNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Stop the current time entry
    public func stopCurrentEntry(in context: ModelContext) {
        guard let entry = activeEntry else { return }
        entry.stop()
        activeEntry = nil
        pomodoroState = .idle
        pomodoroPhaseEndTime = nil
        activePomodoroSettings = nil
        stopPomodoroTimer()
        cancelPomodoroNotifications()

        // Stop GPS tracking
        locationService?.stopTracking()

        // Sync to widgets
        WidgetDataProvider.shared.clearActiveTask()

        try? context.save()
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

    /// Load active entry from database on app launch
    public func loadActiveEntry(from context: ModelContext) {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        if let entries = try? context.fetch(descriptor), let running = entries.first {
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
                activePomodoroSettings = settings
                // Note: We can't fully restore pomodoro progress across app restart
                // Start a fresh work session
                startPomodoroPhase(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak))
            }
        } else {
            // No active entry - ensure widgets are cleared
            WidgetDataProvider.shared.clearActiveTask()
        }
    }

    /// Whether the current pomodoro phase is paused (waiting to start)
    public var isPomodoroPhaseWaiting: Bool {
        pomodoroState.isActive && pomodoroPhaseEndTime == nil
    }

    /// Sync favorite tasks to widgets
    public func syncFavoriteTasks(from context: ModelContext) {
        let descriptor = FetchDescriptor<TrackedTask>(
            predicate: #Predicate { $0.isFavorite && !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        guard let tasks = try? context.fetch(descriptor) else { return }

        let widgetTasks = tasks.prefix(4).map { task in
            (id: task.id.uuidString, name: task.name, colorHex: task.colorHex)
        }

        WidgetDataProvider.shared.setFavoriteTasks(Array(widgetTasks))
    }
}
