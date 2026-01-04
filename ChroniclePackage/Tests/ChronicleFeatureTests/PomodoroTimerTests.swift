import Testing
import Foundation
@testable import ChronicleFeature

@Suite("PomodoroTimer")
@MainActor
struct PomodoroTimerTests {

    // MARK: - Initial State

    @Test("Initial state is idle")
    func initialState() {
        let timer = PomodoroTimer()
        #expect(timer.state == .idle)
        #expect(timer.phaseEndTime == nil)
        #expect(timer.settings == nil)
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

    @Test("isWaiting is false when idle")
    func isWaitingIdle() {
        let timer = PomodoroTimer()
        #expect(timer.isWaiting == false)
    }

    // MARK: - Starting

    @Test("Starting begins work phase")
    func startBeginsWork() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4

        timer.start(with: settings)

        #expect(timer.state == .working(sessionNumber: 1, totalSessions: 4))
        #expect(timer.phaseEndTime != nil)
        #expect(timer.settings != nil)
    }

    @Test("Starting sets phase end time in the future")
    func startSetsEndTime() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.workDuration = 25

        timer.start(with: settings)

        #expect(timer.phaseEndTime != nil)
        #expect(timer.phaseEndTime! > Date())
    }

    @Test("Time remaining is positive after starting")
    func timeRemainingAfterStart() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.workDuration = 25

        timer.start(with: settings)

        #expect(timer.timeRemaining > 0)
        #expect(timer.timeRemaining <= 25 * 60) // 25 minutes in seconds
    }

    // MARK: - Stopping

    @Test("Stop resets to idle")
    func stopResets() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        timer.start(with: settings)

        timer.stop()

        #expect(timer.state == .idle)
        #expect(timer.phaseEndTime == nil)
        #expect(timer.settings == nil)
    }

    @Test("Stop when already idle does nothing")
    func stopWhenIdle() {
        let timer = PomodoroTimer()

        timer.stop() // Should not crash

        #expect(timer.state == .idle)
    }

    // MARK: - Skipping Phases

    @Test("Skip advances from work to short break")
    func skipWorkToShortBreak() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4
        settings.autoStartBreaks = true
        timer.start(with: settings)

        timer.skip()

        #expect(timer.state == .shortBreak(afterSession: 1))
    }

    @Test("Skip advances from short break to next work session")
    func skipShortBreakToWork() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4
        settings.autoStartBreaks = true
        settings.autoStartWork = true
        timer.start(with: settings)

        timer.skip() // Work 1 -> Short break
        timer.skip() // Short break -> Work 2

        #expect(timer.state == .working(sessionNumber: 2, totalSessions: 4))
    }

    @Test("After all sessions, skip goes to long break")
    func skipToLongBreak() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 2
        settings.autoStartBreaks = true
        settings.autoStartWork = true
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

    @Test("Long break skip resets to session 1")
    func skipLongBreakResetsToSession1() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 1
        settings.autoStartBreaks = true
        settings.autoStartWork = true
        timer.start(with: settings)

        timer.skip() // Work 1 -> Long break (since only 1 session)
        #expect(timer.state == .longBreak)

        timer.skip() // Long break -> Work 1
        #expect(timer.state == .working(sessionNumber: 1, totalSessions: 1))
    }

    // MARK: - Auto-Start Behavior

    @Test("With autoStartBreaks off, skip to break but don't start timer")
    func skipWithoutAutoStartBreaks() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4
        settings.autoStartBreaks = false
        timer.start(with: settings)

        timer.skip()

        #expect(timer.state == .shortBreak(afterSession: 1))
        #expect(timer.phaseEndTime == nil) // Timer not started
        #expect(timer.isWaiting == true)
    }

    @Test("With autoStartWork off, skip to work but don't start timer")
    func skipWithoutAutoStartWork() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4
        settings.autoStartBreaks = true
        settings.autoStartWork = false
        timer.start(with: settings)

        timer.skip() // Work -> Short break (auto-started)
        #expect(timer.phaseEndTime != nil)

        timer.skip() // Short break -> Work (not auto-started)
        #expect(timer.state == .working(sessionNumber: 2, totalSessions: 4))
        #expect(timer.phaseEndTime == nil)
        #expect(timer.isWaiting == true)
    }

    // MARK: - Resume

    @Test("Resume starts timer when waiting")
    func resumeStartsTimer() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.autoStartBreaks = false
        timer.start(with: settings)

        timer.skip() // Now in break, waiting
        #expect(timer.isWaiting == true)

        timer.resume()

        #expect(timer.phaseEndTime != nil)
        #expect(timer.isWaiting == false)
    }

    @Test("Resume does nothing when not waiting")
    func resumeDoesNothingWhenRunning() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        timer.start(with: settings)

        let endTime = timer.phaseEndTime
        timer.resume() // Should do nothing

        #expect(timer.phaseEndTime == endTime)
    }

    // MARK: - Reset

    @Test("Reset goes back to session 1")
    func resetToSession1() {
        let timer = PomodoroTimer()
        let settings = PomodoroSettings()
        settings.isEnabled = true
        settings.sessionsBeforeLongBreak = 4
        settings.autoStartBreaks = true
        settings.autoStartWork = true
        timer.start(with: settings)

        timer.skip() // Session 1 -> break
        timer.skip() // Break -> Session 2

        timer.reset()

        #expect(timer.state == .working(sessionNumber: 1, totalSessions: 4))
        #expect(timer.phaseEndTime != nil)
    }

    @Test("Reset when idle does nothing")
    func resetWhenIdle() {
        let timer = PomodoroTimer()

        timer.reset() // Should not crash

        #expect(timer.state == .idle)
    }
}
