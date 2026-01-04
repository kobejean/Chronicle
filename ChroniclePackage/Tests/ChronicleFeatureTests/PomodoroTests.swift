import Testing
import Foundation
import SwiftUI
@testable import ChronicleFeature

@Suite("Pomodoro Tests")
struct PomodoroTests {

    // MARK: - PomodoroSettings

    @Suite("PomodoroSettings")
    struct PomodoroSettingsTests {

        @Test("Default values are correct")
        func defaultValues() {
            let settings = PomodoroSettings()

            #expect(settings.workDuration == 25)
            #expect(settings.shortBreakDuration == 5)
            #expect(settings.longBreakDuration == 15)
            #expect(settings.sessionsBeforeLongBreak == 4)
            #expect(settings.isEnabled == false)
            #expect(settings.autoStartBreaks == true)
            #expect(settings.autoStartWork == false)
        }

        @Test("workTimeInterval converts minutes to seconds")
        func workTimeInterval() {
            let settings = PomodoroSettings()
            settings.workDuration = 25

            #expect(settings.workTimeInterval == 1500) // 25 * 60
        }

        @Test("shortBreakTimeInterval converts minutes to seconds")
        func shortBreakTimeInterval() {
            let settings = PomodoroSettings()
            settings.shortBreakDuration = 5

            #expect(settings.shortBreakTimeInterval == 300) // 5 * 60
        }

        @Test("longBreakTimeInterval converts minutes to seconds")
        func longBreakTimeInterval() {
            let settings = PomodoroSettings()
            settings.longBreakDuration = 15

            #expect(settings.longBreakTimeInterval == 900) // 15 * 60
        }

        @Test("Custom durations convert correctly")
        func customDurations() {
            let settings = PomodoroSettings()
            settings.workDuration = 45
            settings.shortBreakDuration = 10
            settings.longBreakDuration = 30

            #expect(settings.workTimeInterval == 2700) // 45 * 60
            #expect(settings.shortBreakTimeInterval == 600) // 10 * 60
            #expect(settings.longBreakTimeInterval == 1800) // 30 * 60
        }
    }

    // MARK: - PomodoroState

    @Suite("PomodoroState")
    struct PomodoroStateTests {

        @Test("idle state is not active")
        func idleNotActive() {
            let state = TimeTracker.PomodoroState.idle
            #expect(state.isActive == false)
        }

        @Test("working state is active")
        func workingIsActive() {
            let state = TimeTracker.PomodoroState.working(sessionNumber: 1, totalSessions: 4)
            #expect(state.isActive == true)
        }

        @Test("shortBreak state is active")
        func shortBreakIsActive() {
            let state = TimeTracker.PomodoroState.shortBreak(afterSession: 1)
            #expect(state.isActive == true)
        }

        @Test("longBreak state is active")
        func longBreakIsActive() {
            let state = TimeTracker.PomodoroState.longBreak
            #expect(state.isActive == true)
        }

        @Test("displayName for idle")
        func idleDisplayName() {
            #expect(TimeTracker.PomodoroState.idle.displayName == "Idle")
        }

        @Test("displayName for working")
        func workingDisplayName() {
            #expect(TimeTracker.PomodoroState.working(sessionNumber: 2, totalSessions: 4).displayName == "Working")
        }

        @Test("displayName for shortBreak")
        func shortBreakDisplayName() {
            #expect(TimeTracker.PomodoroState.shortBreak(afterSession: 1).displayName == "Short Break")
        }

        @Test("displayName for longBreak")
        func longBreakDisplayName() {
            #expect(TimeTracker.PomodoroState.longBreak.displayName == "Long Break")
        }

        @Test("phaseColor for idle is secondary")
        func idlePhaseColor() {
            #expect(TimeTracker.PomodoroState.idle.phaseColor == .secondary)
        }

        @Test("phaseColor for working is red")
        func workingPhaseColor() {
            #expect(TimeTracker.PomodoroState.working(sessionNumber: 1, totalSessions: 4).phaseColor == .red)
        }

        @Test("phaseColor for shortBreak is green")
        func shortBreakPhaseColor() {
            #expect(TimeTracker.PomodoroState.shortBreak(afterSession: 1).phaseColor == .green)
        }

        @Test("phaseColor for longBreak is blue")
        func longBreakPhaseColor() {
            #expect(TimeTracker.PomodoroState.longBreak.phaseColor == .blue)
        }

        @Test("States with different session numbers are not equal")
        func statesNotEqualDifferentSessions() {
            let state1 = TimeTracker.PomodoroState.working(sessionNumber: 1, totalSessions: 4)
            let state2 = TimeTracker.PomodoroState.working(sessionNumber: 2, totalSessions: 4)
            #expect(state1 != state2)
        }

        @Test("States with same values are equal")
        func statesEqualSameValues() {
            let state1 = TimeTracker.PomodoroState.working(sessionNumber: 1, totalSessions: 4)
            let state2 = TimeTracker.PomodoroState.working(sessionNumber: 1, totalSessions: 4)
            #expect(state1 == state2)
        }
    }

    // MARK: - Session Progression

    @Suite("Session Progression")
    struct SessionProgression {

        @Test("Working sessions track session number")
        func sessionNumberTracking() {
            let session1 = TimeTracker.PomodoroState.working(sessionNumber: 1, totalSessions: 4)
            let session2 = TimeTracker.PomodoroState.working(sessionNumber: 2, totalSessions: 4)
            let session3 = TimeTracker.PomodoroState.working(sessionNumber: 3, totalSessions: 4)
            let session4 = TimeTracker.PomodoroState.working(sessionNumber: 4, totalSessions: 4)

            // All are working states
            #expect(session1.isActive == true)
            #expect(session2.isActive == true)
            #expect(session3.isActive == true)
            #expect(session4.isActive == true)

            // All have same display name
            #expect(session1.displayName == "Working")
            #expect(session4.displayName == "Working")
        }

        @Test("Short breaks track after which session")
        func shortBreakAfterSession() {
            let break1 = TimeTracker.PomodoroState.shortBreak(afterSession: 1)
            let break2 = TimeTracker.PomodoroState.shortBreak(afterSession: 2)
            let break3 = TimeTracker.PomodoroState.shortBreak(afterSession: 3)

            // Different breaks
            #expect(break1 != break2)
            #expect(break2 != break3)

            // All are active and same type
            #expect(break1.displayName == "Short Break")
            #expect(break2.displayName == "Short Break")
            #expect(break3.displayName == "Short Break")
        }
    }
}
