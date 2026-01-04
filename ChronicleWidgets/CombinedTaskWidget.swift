import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Provider

struct CombinedWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CombinedWidgetEntry {
        CombinedWidgetEntry(
            date: Date(),
            activeTaskId: "1",
            activeTaskName: "Work",
            activeTaskColor: .blue,
            activeStartTime: Date().addingTimeInterval(-1800),
            isRunning: true,
            favoriteTasks: [
                WidgetTask(id: "1", name: "Work", color: .blue, isRunning: true),
                WidgetTask(id: "2", name: "Exercise", color: .green, isRunning: false),
                WidgetTask(id: "3", name: "Reading", color: .purple, isRunning: false),
                WidgetTask(id: "4", name: "Coding", color: .orange, isRunning: false)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CombinedWidgetEntry) -> Void) {
        completion(WidgetDataProvider.shared.getCombinedEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CombinedWidgetEntry>) -> Void) {
        let entry = WidgetDataProvider.shared.getCombinedEntry()
        let refreshDate = entry.isRunning
            ? Date().addingTimeInterval(60)
            : Date().addingTimeInterval(300)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

// MARK: - Widget View

struct CombinedWidgetEntryView: View {
    var entry: CombinedWidgetEntry

    var body: some View {
        HStack(spacing: 12) {
            ForEach(entry.favoriteTasks.prefix(4)) { task in
                TaskTile(
                    task: task,
                    isActive: task.id == entry.activeTaskId,
                    startTime: task.id == entry.activeTaskId ? entry.activeStartTime : nil
                )
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Task Tile

struct TaskTile: View {
    let task: WidgetTask
    let isActive: Bool
    let startTime: Date?

    var body: some View {
        Button(intent: ToggleTaskIntent(taskId: task.id)) {
            VStack(spacing: 6) {
                Circle()
                    .fill(task.color.opacity(isActive ? 1.0 : 0.25))
                    .frame(width: 44, height: 44)
                    .overlay {
                        if isActive {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        }
                    }

                Text(task.name)
                    .font(.caption2)
                    .fontWeight(isActive ? .semibold : .regular)
                    .lineLimit(1)
                    .foregroundStyle(isActive ? task.color : .primary)

                if let startTime, isActive {
                    Text(timerInterval: startTime...Date.distantFuture, countsDown: false)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(task.color)
                        .multilineTextAlignment(.center)
                } else {
                    Text(" ")
                        .font(.system(size: 12))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Stop \(task.name)" : "Start \(task.name)")
    }
}

// MARK: - Widget Configuration

struct CombinedTaskWidget: Widget {
    let kind: String = "CombinedTaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CombinedWidgetProvider()) { entry in
            CombinedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Chronicle")
        .description("Quick switch between your favorite tasks.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    CombinedTaskWidget()
} timeline: {
    CombinedWidgetEntry(
        date: Date(),
        activeTaskId: "1",
        activeTaskName: "Work",
        activeTaskColor: .blue,
        activeStartTime: Date().addingTimeInterval(-5628),
        isRunning: true,
        favoriteTasks: [
            WidgetTask(id: "1", name: "Work", color: .blue, isRunning: true),
            WidgetTask(id: "2", name: "Exercise", color: .green, isRunning: false),
            WidgetTask(id: "3", name: "Reading", color: .purple, isRunning: false),
            WidgetTask(id: "4", name: "Coding", color: .orange, isRunning: false)
        ]
    )
    CombinedWidgetEntry(
        date: Date(),
        activeTaskId: nil,
        activeTaskName: nil,
        activeTaskColor: .gray,
        activeStartTime: nil,
        isRunning: false,
        favoriteTasks: [
            WidgetTask(id: "1", name: "Work", color: .blue, isRunning: false),
            WidgetTask(id: "2", name: "Exercise", color: .green, isRunning: false),
            WidgetTask(id: "3", name: "Reading", color: .purple, isRunning: false),
            WidgetTask(id: "4", name: "Coding", color: .orange, isRunning: false)
        ]
    )
}
