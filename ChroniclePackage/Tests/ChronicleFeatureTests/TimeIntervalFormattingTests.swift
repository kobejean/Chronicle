import Testing
import Foundation
@testable import ChronicleFeature

@Suite("TimeInterval Formatting Tests")
struct TimeIntervalFormattingTests {

    // MARK: - shortFormatted

    @Suite("shortFormatted")
    struct ShortFormatted {

        @Test("Formats hours and minutes for long durations")
        func hoursAndMinutes() {
            let interval: TimeInterval = 5400 // 1h 30m
            #expect(interval.shortFormatted == "1h 30m")
        }

        @Test("Formats hours with zero minutes")
        func hoursZeroMinutes() {
            let interval: TimeInterval = 7200 // 2h 0m
            #expect(interval.shortFormatted == "2h 0m")
        }

        @Test("Formats minutes and seconds for medium durations")
        func minutesAndSeconds() {
            let interval: TimeInterval = 185 // 3m 5s
            #expect(interval.shortFormatted == "3m 5s")
        }

        @Test("Formats only seconds for short durations")
        func onlySeconds() {
            let interval: TimeInterval = 45
            #expect(interval.shortFormatted == "45s")
        }

        @Test("Formats zero seconds")
        func zeroSeconds() {
            let interval: TimeInterval = 0
            #expect(interval.shortFormatted == "0s")
        }

        @Test("Truncates partial seconds")
        func truncatesPartialSeconds() {
            let interval: TimeInterval = 65.7 // 1m 5.7s
            #expect(interval.shortFormatted == "1m 5s")
        }
    }

    // MARK: - longFormatted

    @Suite("longFormatted")
    struct LongFormatted {

        @Test("Formats singular hour and minute")
        func singularHourMinute() {
            let interval: TimeInterval = 3660 // 1h 1m
            #expect(interval.longFormatted == "1 hour 1 minute")
        }

        @Test("Formats plural hours and minutes")
        func pluralHoursMinutes() {
            let interval: TimeInterval = 9000 // 2h 30m
            #expect(interval.longFormatted == "2 hours 30 minutes")
        }

        @Test("Formats singular minute and second")
        func singularMinuteSecond() {
            let interval: TimeInterval = 61 // 1m 1s
            #expect(interval.longFormatted == "1 minute 1 second")
        }

        @Test("Formats plural minutes and seconds")
        func pluralMinutesSeconds() {
            let interval: TimeInterval = 185 // 3m 5s
            #expect(interval.longFormatted == "3 minutes 5 seconds")
        }

        @Test("Formats singular second")
        func singularSecond() {
            let interval: TimeInterval = 1
            #expect(interval.longFormatted == "1 second")
        }

        @Test("Formats plural seconds")
        func pluralSeconds() {
            let interval: TimeInterval = 45
            #expect(interval.longFormatted == "45 seconds")
        }

        @Test("Formats zero seconds")
        func zeroSeconds() {
            let interval: TimeInterval = 0
            #expect(interval.longFormatted == "0 seconds")
        }
    }

    // MARK: - timerFormatted

    @Suite("timerFormatted")
    struct TimerFormatted {

        @Test("Formats with hours when >= 1 hour")
        func withHours() {
            let interval: TimeInterval = 3661 // 1:01:01
            #expect(interval.timerFormatted == "1:01:01")
        }

        @Test("Formats large hours correctly")
        func largeHours() {
            let interval: TimeInterval = 36000 // 10:00:00
            #expect(interval.timerFormatted == "10:00:00")
        }

        @Test("Formats without hours when < 1 hour")
        func withoutHours() {
            let interval: TimeInterval = 125 // 02:05
            #expect(interval.timerFormatted == "02:05")
        }

        @Test("Formats zero duration")
        func zeroDuration() {
            let interval: TimeInterval = 0
            #expect(interval.timerFormatted == "00:00")
        }

        @Test("Pads single digit minutes and seconds")
        func padsSingleDigits() {
            let interval: TimeInterval = 65 // 01:05
            #expect(interval.timerFormatted == "01:05")
        }

        @Test("Handles exactly one hour")
        func exactlyOneHour() {
            let interval: TimeInterval = 3600 // 1:00:00
            #expect(interval.timerFormatted == "1:00:00")
        }
    }

    // MARK: - percentageOf

    @Suite("percentageOf")
    struct PercentageOf {

        @Test("Calculates 50% correctly")
        func fiftyPercent() {
            let current: TimeInterval = 1800 // 30 min
            let goal: TimeInterval = 3600 // 60 min
            #expect(current.percentageOf(goal) == "50%")
        }

        @Test("Calculates 100% correctly")
        func oneHundredPercent() {
            let current: TimeInterval = 3600
            let goal: TimeInterval = 3600
            #expect(current.percentageOf(goal) == "100%")
        }

        @Test("Caps display at 999% for exceeded goals")
        func capsAtNineNineNine() {
            let current: TimeInterval = 36000 // 10x the goal
            let goal: TimeInterval = 3600
            #expect(current.percentageOf(goal) == "999%")
        }

        @Test("Returns 0% for zero goal")
        func zeroGoal() {
            let current: TimeInterval = 1800
            let goal: TimeInterval = 0
            #expect(current.percentageOf(goal) == "0%")
        }

        @Test("Returns 0% for zero current")
        func zeroCurrent() {
            let current: TimeInterval = 0
            let goal: TimeInterval = 3600
            #expect(current.percentageOf(goal) == "0%")
        }

        @Test("Rounds to nearest whole number")
        func roundsPercentage() {
            let current: TimeInterval = 1000
            let goal: TimeInterval = 3000 // 33.33%
            #expect(current.percentageOf(goal) == "33%")
        }

        @Test("Handles over 100% but under cap")
        func overOneHundred() {
            let current: TimeInterval = 5400 // 150%
            let goal: TimeInterval = 3600
            #expect(current.percentageOf(goal) == "150%")
        }
    }
}
