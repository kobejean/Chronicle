import SwiftUI
import Observation
import AudioToolbox
import UserNotifications

/// Pomodoro state representing the current phase of the timer
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

/// Dedicated pomodoro timer service
@Observable
@MainActor
public final class PomodoroTimer {

    // MARK: - Public State

    public private(set) var state: PomodoroState = .idle
    public private(set) var phaseEndTime: Date?
    public private(set) var settings: PomodoroSettings?

    // MARK: - Computed Properties

    /// Remaining time in current phase
    public var timeRemaining: TimeInterval {
        guard let endTime = phaseEndTime else { return 0 }
        return max(0, endTime.timeIntervalSinceNow)
    }

    /// Progress of current phase (0.0 to 1.0)
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

    /// Whether the timer is in an active phase but waiting to start
    public var isWaiting: Bool {
        state.isActive && phaseEndTime == nil
    }

    // MARK: - Private

    private var timer: Timer?

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Public Methods

    /// Start a new pomodoro session with the given settings
    public func start(with settings: PomodoroSettings) {
        self.settings = settings
        startPhase(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak))
    }

    /// Stop the pomodoro timer completely
    public func stop() {
        state = .idle
        phaseEndTime = nil
        settings = nil
        stopTimer()
        cancelNotifications()
    }

    /// Skip to the next phase
    public func skip() {
        transitionToNextPhase()
    }

    /// Resume a waiting phase (start the timer)
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

    /// Reset to the beginning (session 1)
    public func reset() {
        guard let settings else { return }
        startPhase(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak))
    }

    // MARK: - Private Methods

    private func startPhase(_ newState: PomodoroState) {
        guard let settings else { return }

        state = newState

        let duration: TimeInterval
        switch newState {
        case .working:
            duration = settings.workTimeInterval
        case .shortBreak:
            duration = settings.shortBreakTimeInterval
        case .longBreak:
            duration = settings.longBreakTimeInterval
        case .idle:
            phaseEndTime = nil
            stopTimer()
            return
        }

        phaseEndTime = Date().addingTimeInterval(duration)
        startTimer()
        scheduleNotification(for: newState, in: duration)
    }

    private func setPhaseWithoutTimer(_ newState: PomodoroState) {
        state = newState
        phaseEndTime = nil
        stopTimer()
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
                    setPhaseWithoutTimer(.longBreak)
                }
            } else {
                // Short break
                if settings.autoStartBreaks {
                    startPhase(.shortBreak(afterSession: session))
                } else {
                    setPhaseWithoutTimer(.shortBreak(afterSession: session))
                }
            }

        case .shortBreak(let afterSession):
            let nextSession = afterSession + 1
            if settings.autoStartWork {
                startPhase(.working(sessionNumber: nextSession, totalSessions: settings.sessionsBeforeLongBreak))
            } else {
                setPhaseWithoutTimer(.working(sessionNumber: nextSession, totalSessions: settings.sessionsBeforeLongBreak))
            }

        case .longBreak:
            if settings.autoStartWork {
                startPhase(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak))
            } else {
                setPhaseWithoutTimer(.working(sessionNumber: 1, totalSessions: settings.sessionsBeforeLongBreak))
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
