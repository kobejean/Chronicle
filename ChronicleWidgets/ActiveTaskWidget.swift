import WidgetKit
import SwiftUI

struct ActiveTaskEntry: TimelineEntry {
    let date: Date
    let taskName: String?
    let taskColor: Color
    let startTime: Date?
    let isRunning: Bool
}

struct ActiveTaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActiveTaskEntry {
        ActiveTaskEntry(
            date: Date(),
            taskName: "Working",
            taskColor: .blue,
            startTime: Date().addingTimeInterval(-1800),
            isRunning: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ActiveTaskEntry) -> Void) {
        let entry = WidgetDataProvider.shared.getCurrentTaskEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveTaskEntry>) -> Void) {
        let entry = WidgetDataProvider.shared.getCurrentTaskEntry()

        // Update every minute when running, less frequently when idle
        let refreshDate = entry.isRunning
            ? Date().addingTimeInterval(60)
            : Date().addingTimeInterval(300)

        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

struct ActiveTaskWidgetEntryView: View {
    var entry: ActiveTaskEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .systemSmall:
            smallView
        default:
            smallView
        }
    }

    private var accessoryCircularView: some View {
        ZStack {
            if entry.isRunning {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "timer")
                        .font(.title3)
                    if let start = entry.startTime {
                        Text(start, style: .timer)
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            } else {
                AccessoryWidgetBackground()
                Image(systemName: "clock")
                    .font(.title2)
            }
        }
    }

    private var accessoryRectangularView: some View {
        HStack {
            if entry.isRunning, let taskName = entry.taskName {
                VStack(alignment: .leading, spacing: 2) {
                    Text(taskName)
                        .font(.headline)
                        .lineLimit(1)
                    if let start = entry.startTime {
                        Text(start, style: .timer)
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                Spacer()
                Image(systemName: "timer")
            } else {
                Text("No task running")
                    .font(.caption)
                Spacer()
                Image(systemName: "clock")
            }
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.isRunning ? "timer" : "clock")
                    .foregroundStyle(entry.taskColor)
                Spacer()
            }

            Spacer()

            if entry.isRunning, let taskName = entry.taskName {
                Text(taskName)
                    .font(.headline)
                    .lineLimit(2)

                if let start = entry.startTime {
                    Text(start, style: .timer)
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundStyle(entry.taskColor)
                }
            } else {
                Text("No task running")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Tap to start")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct ActiveTaskWidget: Widget {
    let kind: String = "ActiveTaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActiveTaskProvider()) { entry in
            ActiveTaskWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Active Task")
        .description("Shows your currently running task and timer.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .systemSmall) {
    ActiveTaskWidget()
} timeline: {
    ActiveTaskEntry(date: Date(), taskName: "Working", taskColor: .blue, startTime: Date().addingTimeInterval(-1800), isRunning: true)
    ActiveTaskEntry(date: Date(), taskName: nil, taskColor: .gray, startTime: nil, isRunning: false)
}
