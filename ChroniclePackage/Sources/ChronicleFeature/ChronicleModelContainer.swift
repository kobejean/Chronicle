@preconcurrency import SwiftData
import Foundation

/// All Chronicle SwiftData models
public let chronicleSchema = Schema([
    TrackedTask.self,
    TimeEntry.self,
    PomodoroSettings.self,
    Place.self,
    GPSPoint.self,
    DiaryEntry.self,
    Goal.self,
    Streak.self
])

/// Creates the ModelContainer for Chronicle
/// - Note: CloudKit sync is disabled for development. Enable once Apple Developer account is configured.
/// - TODO: Re-enable CloudKit by changing `.none` to `.private("iCloud.chronicle")` after:
///   1. Creating the CloudKit container in Apple Developer portal
///   2. Enabling iCloud capability in Xcode signing
///   3. Testing on a real device with iCloud signed in
public func createChronicleModelContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(
        schema: chronicleSchema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none  // TODO: Change to .private("iCloud.chronicle") when ready
    )

    let container = try ModelContainer(
        for: chronicleSchema,
        configurations: [configuration]
    )

    return container
}

/// Creates a preview ModelContainer (in-memory, no CloudKit)
public func createPreviewModelContainer() -> ModelContainer {
    let configuration = ModelConfiguration(
        schema: chronicleSchema,
        isStoredInMemoryOnly: true
    )

    do {
        return try ModelContainer(for: chronicleSchema, configurations: [configuration])
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
}

/// Sample data for previews
@MainActor
public func populatePreviewData(in context: ModelContext) {
    // Create sample tasks
    let workTask = TrackedTask(name: "Work", colorHex: TaskColor.blue.rawValue)
    workTask.isFavorite = true

    let exerciseTask = TrackedTask(name: "Exercise", colorHex: TaskColor.green.rawValue)
    exerciseTask.isFavorite = true

    let readingTask = TrackedTask(name: "Reading", colorHex: TaskColor.purple.rawValue)

    let codingTask = TrackedTask(name: "Coding", colorHex: TaskColor.orange.rawValue)
    codingTask.isFavorite = true

    context.insert(workTask)
    context.insert(exerciseTask)
    context.insert(readingTask)
    context.insert(codingTask)

    // Create sample time entries
    let now = Date()
    let calendar = Calendar.current

    // Entry from earlier today
    if let startTime = calendar.date(byAdding: .hour, value: -3, to: now) {
        let entry = TimeEntry(task: workTask, startTime: startTime)
        entry.endTime = calendar.date(byAdding: .hour, value: 2, to: startTime)
        context.insert(entry)
    }

    // Currently running entry
    if let startTime = calendar.date(byAdding: .minute, value: -45, to: now) {
        let entry = TimeEntry(task: codingTask, startTime: startTime)
        context.insert(entry)
    }

    // Add pomodoro settings to coding task
    let pomodoroSettings = PomodoroSettings()
    pomodoroSettings.isEnabled = true
    pomodoroSettings.workDuration = 25
    pomodoroSettings.shortBreakDuration = 5
    pomodoroSettings.task = codingTask
    context.insert(pomodoroSettings)

    // Add a daily goal
    let dailyGoal = Goal(task: codingTask, targetMinutes: 120, goalType: .daily)
    context.insert(dailyGoal)

    try? context.save()
}
