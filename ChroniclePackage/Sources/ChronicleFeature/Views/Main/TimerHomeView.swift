import SwiftUI
import SwiftData

public struct TimerHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimeTracker.self) private var timeTracker

    @Query(filter: #Predicate<TrackedTask> { !$0.isArchived }, sort: \TrackedTask.sortOrder)
    private var tasks: [TrackedTask]

    private var favoriteTasks: [TrackedTask] {
        tasks.filter { $0.isFavorite }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Active Timer Card
                    ActiveTimerCard()

                    // Quick Start Section
                    if !favoriteTasks.isEmpty {
                        QuickStartSection(tasks: favoriteTasks)
                    }

                    // Recent Tasks
                    RecentTasksSection(tasks: Array(tasks.prefix(6)))
                }
                .padding()
            }
            .navigationTitle("Chronicle")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
            .task {
                timeTracker.loadActiveEntry(from: modelContext)
            }
        }
    }

    public init() {}
}

struct ActiveTimerCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimeTracker.self) private var timeTracker

    var body: some View {
        VStack(spacing: 16) {
            if let entry = timeTracker.activeEntry, let task = entry.task {
                // Active task display
                HStack {
                    Circle()
                        .fill(task.color)
                        .frame(width: 12, height: 12)
                    Text(task.name)
                        .font(.headline)
                    Spacer()
                    Button {
                        timeTracker.stopCurrentEntry(in: modelContext)
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                    }
                }

                // Pomodoro or regular timer display
                if timeTracker.pomodoroState.isActive {
                    PomodoroTimerDisplay()
                } else {
                    // Regular timer display
                    Text(entry.startTime, style: .timer)
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .monospacedDigit()
                }
            } else {
                // Idle state
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No task running")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Tap a task below to start tracking")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PomodoroTimerDisplay: View {
    @Environment(TimeTracker.self) private var timeTracker

    var body: some View {
        VStack(spacing: 12) {
            // Phase indicator
            HStack(spacing: 8) {
                Image(systemName: phaseIcon)
                    .foregroundStyle(timeTracker.pomodoroState.phaseColor)
                Text(timeTracker.pomodoroState.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(timeTracker.pomodoroState.phaseColor)

                if case let .working(session, total) = timeTracker.pomodoroState {
                    Text("(\(session)/\(total))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Timer ring with countdown
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 140, height: 140)

                // Progress ring
                Circle()
                    .trim(from: 0, to: timeTracker.pomodoroProgress)
                    .stroke(
                        timeTracker.pomodoroState.phaseColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: timeTracker.pomodoroProgress)

                // Time remaining
                VStack(spacing: 4) {
                    if timeTracker.isPomodoroPhaseWaiting {
                        Text("Paused")
                            .font(.system(size: 24, weight: .light, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(formatTime(timeTracker.pomodoroTimeRemaining))
                            .font(.system(size: 32, weight: .light, design: .monospaced))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
            }

            // Control buttons
            HStack(spacing: 24) {
                if timeTracker.isPomodoroPhaseWaiting {
                    // Start button when paused
                    Button {
                        timeTracker.startNextPomodoroPhase()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(timeTracker.pomodoroState.phaseColor)
                } else {
                    // Skip button
                    Button {
                        timeTracker.skipPomodoroPhase()
                    } label: {
                        Label("Skip", systemImage: "forward.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    // Reset button
                    Button {
                        timeTracker.resetPomodoro()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var phaseIcon: String {
        switch timeTracker.pomodoroState {
        case .idle:
            return "clock"
        case .working:
            return "brain.head.profile"
        case .shortBreak:
            return "cup.and.saucer"
        case .longBreak:
            return "figure.walk"
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct QuickStartSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimeTracker.self) private var timeTracker
    let tasks: [TrackedTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(tasks) { task in
                    QuickTaskButton(task: task) {
                        if timeTracker.isTracking(task) {
                            timeTracker.stopCurrentEntry(in: modelContext)
                        } else {
                            timeTracker.switchTask(to: task, in: modelContext)
                        }
                    }
                }
            }
        }
    }
}

struct QuickTaskButton: View {
    let task: TrackedTask
    let action: () -> Void
    @Environment(TimeTracker.self) private var timeTracker

    private var isActive: Bool {
        timeTracker.isTracking(task)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(task.color.opacity(isActive ? 1.0 : 0.2))
                        .frame(width: 44, height: 44)

                    if isActive {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.white)
                    } else if let iconName = task.iconName {
                        Image(systemName: iconName)
                            .foregroundStyle(task.color)
                    }
                }

                Text(task.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isActive ? task.color : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct RecentTasksSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimeTracker.self) private var timeTracker
    let tasks: [TrackedTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Tasks")
                .font(.headline)

            ForEach(tasks) { task in
                TaskRowButton(task: task) {
                    if timeTracker.isTracking(task) {
                        timeTracker.stopCurrentEntry(in: modelContext)
                    } else {
                        timeTracker.switchTask(to: task, in: modelContext)
                    }
                }
            }
        }
    }
}

struct TaskRowButton: View {
    let task: TrackedTask
    let action: () -> Void
    @Environment(TimeTracker.self) private var timeTracker

    private var isActive: Bool {
        timeTracker.isTracking(task)
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(task.color)
                    .frame(width: 12, height: 12)

                Text(task.name)
                    .foregroundStyle(.primary)

                Spacer()

                Text(task.todayDuration.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isActive {
                    Image(systemName: "stop.circle.fill")
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "play.circle")
                        .foregroundStyle(task.color)
                }
            }
            .padding()
            .background(isActive ? task.color.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView: View {
    var body: some View {
        List {
            Section("General") {
                NavigationLink("Notifications") {
                    Text("Notification Settings")
                }
                NavigationLink("Location") {
                    Text("Location Settings")
                }
            }

            Section("Data") {
                NavigationLink("iCloud Sync") {
                    Text("Sync Status")
                }
                NavigationLink("Export Data") {
                    Text("Export Options")
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    let container = createPreviewModelContainer()
    return NavigationStack {
        TimerHomeView()
    }
    .modelContainer(container)
    .environment(TimeTracker())
    .onAppear {
        populatePreviewData(in: container.mainContext)
    }
}
