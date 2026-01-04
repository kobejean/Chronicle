import Foundation
import SwiftUI
import WidgetKit

// MARK: - Pending Widget Action

enum PendingWidgetAction: Codable {
    case start(taskId: String)
    case stop(taskId: String)
}

/// Provides shared data access between the main app and widgets via App Groups
/// Note: Thread-safe for widget timeline providers (UserDefaults is thread-safe)
final class WidgetDataProvider: @unchecked Sendable {
    static let shared = WidgetDataProvider()

    private let appGroupIdentifier = "group.chronicle.shared"
    private let activeTaskKey = "activeTask"
    private let favoriteTasksKey = "favoriteTasks"
    private let pendingActionKey = "pendingWidgetAction"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    // MARK: - Active Task

    func getCurrentTaskEntry() -> ActiveTaskEntry {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: activeTaskKey),
              let activeTask = try? JSONDecoder().decode(SharedActiveTask.self, from: data) else {
            return ActiveTaskEntry(
                date: Date(),
                taskName: nil,
                taskColor: .gray,
                startTime: nil,
                isRunning: false
            )
        }

        return ActiveTaskEntry(
            date: Date(),
            taskName: activeTask.name,
            taskColor: Color(hex: activeTask.colorHex) ?? .blue,
            startTime: activeTask.startTime,
            isRunning: true
        )
    }

    func setActiveTask(id: String, name: String, colorHex: String, startTime: Date) {
        guard let defaults = userDefaults else { return }
        let task = SharedActiveTask(id: id, name: name, colorHex: colorHex, startTime: startTime)
        if let data = try? JSONEncoder().encode(task) {
            defaults.set(data, forKey: activeTaskKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "ActiveTaskWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FavoriteTasksWidget")
    }

    func clearActiveTask() {
        userDefaults?.removeObject(forKey: activeTaskKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "ActiveTaskWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FavoriteTasksWidget")
    }

    // MARK: - Favorite Tasks

    func getFavoriteTasksEntry() -> FavoriteTasksEntry {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: favoriteTasksKey),
              let tasks = try? JSONDecoder().decode([SharedTask].self, from: data) else {
            return FavoriteTasksEntry(date: Date(), tasks: [])
        }

        let activeTaskId = getActiveTaskId()

        let widgetTasks = tasks.map { task in
            WidgetTask(
                id: task.id,
                name: task.name,
                color: Color(hex: task.colorHex) ?? .blue,
                isRunning: task.id == activeTaskId
            )
        }

        return FavoriteTasksEntry(date: Date(), tasks: widgetTasks)
    }

    func setFavoriteTasks(_ tasks: [(id: String, name: String, colorHex: String)]) {
        guard let defaults = userDefaults else { return }
        let sharedTasks = tasks.map { SharedTask(id: $0.id, name: $0.name, colorHex: $0.colorHex) }
        if let data = try? JSONEncoder().encode(sharedTasks) {
            defaults.set(data, forKey: favoriteTasksKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "FavoriteTasksWidget")
    }

    // MARK: - Pending Actions

    func setPendingAction(_ action: PendingWidgetAction) {
        guard let defaults = userDefaults else { return }
        if let data = try? JSONEncoder().encode(action) {
            defaults.set(data, forKey: pendingActionKey)
        }
    }

    func getPendingAction() -> PendingWidgetAction? {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: pendingActionKey),
              let action = try? JSONDecoder().decode(PendingWidgetAction.self, from: data) else {
            return nil
        }
        return action
    }

    func clearPendingAction() {
        userDefaults?.removeObject(forKey: pendingActionKey)
    }

    // MARK: - Combined Entry

    func getCombinedEntry() -> CombinedWidgetEntry {
        let activeEntry = getCurrentTaskEntry()
        let favoriteEntry = getFavoriteTasksEntry()

        return CombinedWidgetEntry(
            date: Date(),
            activeTaskId: getActiveTaskId(),
            activeTaskName: activeEntry.taskName,
            activeTaskColor: activeEntry.taskColor,
            activeStartTime: activeEntry.startTime,
            isRunning: activeEntry.isRunning,
            favoriteTasks: favoriteEntry.tasks
        )
    }

    // MARK: - Helper Methods

    func getActiveTaskId() -> String? {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: activeTaskKey),
              let activeTask = try? JSONDecoder().decode(SharedActiveTask.self, from: data) else {
            return nil
        }
        return activeTask.id
    }

    func getFavoriteTask(id: String) -> SharedTask? {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: favoriteTasksKey),
              let tasks = try? JSONDecoder().decode([SharedTask].self, from: data) else {
            return nil
        }
        return tasks.first { $0.id == id }
    }
}

// MARK: - Widget Entry Types

struct ActiveTaskEntry: TimelineEntry {
    let date: Date
    let taskName: String?
    let taskColor: Color
    let startTime: Date?
    let isRunning: Bool
}

struct FavoriteTasksEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
}

struct WidgetTask: Identifiable {
    let id: String
    let name: String
    let color: Color
    let isRunning: Bool
}

struct CombinedWidgetEntry: TimelineEntry {
    let date: Date
    let activeTaskId: String?
    let activeTaskName: String?
    let activeTaskColor: Color
    let activeStartTime: Date?
    let isRunning: Bool
    let favoriteTasks: [WidgetTask]
}

// MARK: - Shared Data Models

struct SharedActiveTask: Codable {
    let id: String
    let name: String
    let colorHex: String
    let startTime: Date

    init(id: String, name: String, colorHex: String, startTime: Date) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.startTime = startTime
    }
}

struct SharedTask: Codable {
    let id: String
    let name: String
    let colorHex: String
}

// MARK: - Color Extension for Widgets

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
