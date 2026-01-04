import Testing
import Foundation
@testable import ChronicleFeature

@Suite("TimeEntry Tests")
struct TimeEntryTests {

    // MARK: - Duration Calculation

    @Test("Duration calculates correctly for completed entry")
    func durationForCompletedEntry() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1 hour later

        let entry = TimeEntry(task: nil, startTime: startTime)
        entry.endTime = endTime

        #expect(entry.duration == 3600)
    }

    @Test("Duration calculates from now for running entry")
    func durationForRunningEntry() {
        let startTime = Date().addingTimeInterval(-1800) // Started 30 min ago

        let entry = TimeEntry(task: nil, startTime: startTime)

        // Should be approximately 1800 seconds (30 min)
        #expect(entry.duration >= 1799 && entry.duration <= 1801)
    }

    @Test("Duration is zero for entry that just started")
    func durationForNewEntry() {
        let entry = TimeEntry(task: nil, startTime: Date())

        #expect(entry.duration >= 0 && entry.duration < 1)
    }

    // MARK: - isRunning

    @Test("isRunning is true when endTime is nil")
    func isRunningWhenNoEndTime() {
        let entry = TimeEntry(task: nil, startTime: Date())

        #expect(entry.isRunning == true)
    }

    @Test("isRunning is false when endTime is set")
    func isNotRunningWhenEndTimeSet() {
        let entry = TimeEntry(task: nil, startTime: Date())
        entry.endTime = Date()

        #expect(entry.isRunning == false)
    }

    // MARK: - stop()

    @Test("stop() sets endTime when entry is running")
    func stopSetsEndTime() {
        let entry = TimeEntry(task: nil, startTime: Date())

        #expect(entry.endTime == nil)

        entry.stop()

        #expect(entry.endTime != nil)
        #expect(entry.isRunning == false)
    }

    @Test("stop() does not change endTime if already stopped")
    func stopDoesNotChangeExistingEndTime() {
        let entry = TimeEntry(task: nil, startTime: Date())
        let originalEndTime = Date().addingTimeInterval(-3600)
        entry.endTime = originalEndTime

        entry.stop()

        #expect(entry.endTime == originalEndTime)
    }

    // MARK: - formattedDuration

    @Test("formattedDuration shows hours and minutes for long entries")
    func formattedDurationWithHours() {
        let startTime = Date()
        let entry = TimeEntry(task: nil, startTime: startTime)
        entry.endTime = startTime.addingTimeInterval(5025) // 1h 23m 45s

        #expect(entry.formattedDuration == "1h 23m")
    }

    @Test("formattedDuration shows minutes and seconds for medium entries")
    func formattedDurationWithMinutes() {
        let startTime = Date()
        let entry = TimeEntry(task: nil, startTime: startTime)
        entry.endTime = startTime.addingTimeInterval(125) // 2m 5s

        #expect(entry.formattedDuration == "2m 5s")
    }

    @Test("formattedDuration shows only seconds for short entries")
    func formattedDurationOnlySeconds() {
        let startTime = Date()
        let entry = TimeEntry(task: nil, startTime: startTime)
        entry.endTime = startTime.addingTimeInterval(45)

        #expect(entry.formattedDuration == "45s")
    }

    @Test("formattedDuration shows 0s for zero duration")
    func formattedDurationZero() {
        let startTime = Date()
        let entry = TimeEntry(task: nil, startTime: startTime)
        entry.endTime = startTime

        #expect(entry.formattedDuration == "0s")
    }
}
