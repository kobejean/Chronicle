import Foundation
import SwiftUI
import WidgetKit

/// Provides shared data access between the main app and widgets via App Groups
@MainActor
public final class WidgetDataProvider: Sendable {
    public static let shared = WidgetDataProvider()

    private let appGroupIdentifier = "group.chronicle.shared"
    private let activeTaskKey = "activeTask"
    private let favoriteTasksKey = "favoriteTasks"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    // MARK: - Active Task

    /// Set the currently active task for widget display
    public func setActiveTask(id: String, name: String, colorHex: String, startTime: Date) {
        guard let defaults = userDefaults else { return }
        let task = SharedActiveTask(id: id, name: name, colorHex: colorHex, startTime: startTime)
        if let data = try? JSONEncoder().encode(task) {
            defaults.set(data, forKey: activeTaskKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "ActiveTaskWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FavoriteTasksWidget")
    }

    /// Clear the active task (when stopping tracking)
    public func clearActiveTask() {
        userDefaults?.removeObject(forKey: activeTaskKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "ActiveTaskWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FavoriteTasksWidget")
    }

    // MARK: - Favorite Tasks

    /// Update the list of favorite tasks for quick-start widget
    public func setFavoriteTasks(_ tasks: [(id: String, name: String, colorHex: String)]) {
        guard let defaults = userDefaults else { return }
        let sharedTasks = tasks.map { SharedTask(id: $0.id, name: $0.name, colorHex: $0.colorHex) }
        if let data = try? JSONEncoder().encode(sharedTasks) {
            defaults.set(data, forKey: favoriteTasksKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "FavoriteTasksWidget")
    }

    /// Reload all widget timelines
    public func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Shared Data Models

/// Active task data shared between app and widgets
public struct SharedActiveTask: Codable, Sendable {
    public let id: String
    public let name: String
    public let colorHex: String
    public let startTime: Date

    public init(id: String, name: String, colorHex: String, startTime: Date) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.startTime = startTime
    }
}

/// Task data shared between app and widgets
public struct SharedTask: Codable, Sendable {
    public let id: String
    public let name: String
    public let colorHex: String

    public init(id: String, name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}
