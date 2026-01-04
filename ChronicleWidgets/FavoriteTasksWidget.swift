import WidgetKit
import SwiftUI
import AppIntents

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

struct FavoriteTasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoriteTasksEntry {
        FavoriteTasksEntry(date: Date(), tasks: [
            WidgetTask(id: "1", name: "Work", color: .blue, isRunning: true),
            WidgetTask(id: "2", name: "Exercise", color: .green, isRunning: false),
            WidgetTask(id: "3", name: "Reading", color: .purple, isRunning: false),
            WidgetTask(id: "4", name: "Coding", color: .orange, isRunning: false)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoriteTasksEntry) -> Void) {
        let entry = WidgetDataProvider.shared.getFavoriteTasksEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoriteTasksEntry>) -> Void) {
        let entry = WidgetDataProvider.shared.getFavoriteTasksEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }
}

struct FavoriteTasksWidgetEntryView: View {
    var entry: FavoriteTasksEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Start")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(entry.tasks.prefix(4)) { task in
                    TaskButton(task: task)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Start")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(entry.tasks.prefix(4)) { task in
                    TaskButton(task: task)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct TaskButton: View {
    let task: WidgetTask

    var body: some View {
        Button(intent: ToggleTaskIntent(taskId: task.id)) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(task.color.opacity(task.isRunning ? 1.0 : 0.2))
                        .frame(width: 36, height: 36)

                    if task.isRunning {
                        Image(systemName: "stop.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }

                Text(task.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(task.isRunning ? task.color : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FavoriteTasksWidget: Widget {
    let kind: String = "FavoriteTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoriteTasksProvider()) { entry in
            FavoriteTasksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Favorite Tasks")
        .description("Quick access to your favorite tasks.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - App Intent for Interactive Widgets

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    static var description = IntentDescription("Start or stop tracking a task")

    @Parameter(title: "Task ID")
    var taskId: String

    init() {
        self.taskId = ""
    }

    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        // Toggle the task in the shared data store
        await WidgetDataProvider.shared.toggleTask(id: taskId)
        return .result()
    }
}

#Preview(as: .systemSmall) {
    FavoriteTasksWidget()
} timeline: {
    FavoriteTasksEntry(date: Date(), tasks: [
        WidgetTask(id: "1", name: "Work", color: .blue, isRunning: true),
        WidgetTask(id: "2", name: "Exercise", color: .green, isRunning: false),
        WidgetTask(id: "3", name: "Reading", color: .purple, isRunning: false),
        WidgetTask(id: "4", name: "Coding", color: .orange, isRunning: false)
    ])
}
