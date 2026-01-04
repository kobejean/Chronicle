import Foundation
import SwiftUI
import WidgetKit

/// Provides shared data access between the main app and widgets via App Groups
@MainActor
final class WidgetDataProvider {
    static let shared = WidgetDataProvider()

    private let appGroupIdentifier = "group.chronicle.shared"
    private let activeTaskKey = "activeTask"
    private let favoriteTasksKey = "favoriteTasks"

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

    func setActiveTask(name: String, colorHex: String, startTime: Date) {
        guard let defaults = userDefaults else { return }
        let task = SharedActiveTask(name: name, colorHex: colorHex, startTime: startTime)
        if let data = try? JSONEncoder().encode(task) {
            defaults.set(data, forKey: activeTaskKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "ActiveTaskWidget")
    }

    func clearActiveTask() {
        userDefaults?.removeObject(forKey: activeTaskKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "ActiveTaskWidget")
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

    func toggleTask(id: String) async {
        // This will be called from the widget intent
        // The main app should handle the actual toggling via App Intents
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func getActiveTaskId() -> String? {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: activeTaskKey),
              let activeTask = try? JSONDecoder().decode(SharedActiveTask.self, from: data) else {
            return nil
        }
        return activeTask.id
    }
}

// MARK: - Shared Data Models

struct SharedActiveTask: Codable {
    let id: String
    let name: String
    let colorHex: String
    let startTime: Date

    init(name: String, colorHex: String, startTime: Date) {
        self.id = UUID().uuidString
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
