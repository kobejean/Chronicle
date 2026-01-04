import SwiftUI
import SwiftData

public struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimeTracker.self) private var timeTracker
    @Query(sort: \TrackedTask.sortOrder) private var tasks: [TrackedTask]
    @State private var showingAddTask = false

    private var activeTasks: [TrackedTask] {
        tasks.filter { !$0.isArchived }
    }

    private var archivedTasks: [TrackedTask] {
        tasks.filter { $0.isArchived }
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Active Tasks") {
                    ForEach(activeTasks) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            TaskRow(task: task)
                        }
                    }
                    .onDelete(perform: deleteActiveTasks)
                    .onMove(perform: moveActiveTasks)
                }

                if !archivedTasks.isEmpty {
                    Section("Archived") {
                        ForEach(archivedTasks) { task in
                            NavigationLink(destination: TaskDetailView(task: task)) {
                                TaskRow(task: task)
                            }
                        }
                        .onDelete(perform: deleteArchivedTasks)
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskSheet()
            }
        }
    }

    private func deleteActiveTasks(at offsets: IndexSet) {
        var deletedFavorite = false
        for index in offsets {
            let task = activeTasks[index]
            if task.isFavorite {
                deletedFavorite = true
            }
            modelContext.delete(task)
        }
        if deletedFavorite {
            timeTracker.syncFavoriteTasks(from: modelContext)
        }
    }

    private func deleteArchivedTasks(at offsets: IndexSet) {
        for index in offsets {
            let task = archivedTasks[index]
            modelContext.delete(task)
        }
    }

    private func moveActiveTasks(from source: IndexSet, to destination: Int) {
        var tasks = activeTasks
        tasks.move(fromOffsets: source, toOffset: destination)
        for (index, task) in tasks.enumerated() {
            task.sortOrder = index
        }
        // Sync favorites as order may have changed
        timeTracker.syncFavoriteTasks(from: modelContext)
    }

    public init() {}
}

struct TaskRow: View {
    let task: TrackedTask

    var body: some View {
        HStack {
            Circle()
                .fill(task.color)
                .frame(width: 12, height: 12)

            Text(task.name)

            if task.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            Spacer()

            Text(task.todayDuration.shortFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct AddTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(TimeTracker.self) private var timeTracker

    @State private var name = ""
    @State private var selectedColor: TaskColor = .blue
    @State private var isFavorite = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task Name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(TaskColor.allCases, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .font(.headline)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Toggle("Add to Favorites", isOn: $isFavorite)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTask()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func addTask() {
        let task = TrackedTask(name: name, colorHex: selectedColor.rawValue)
        task.isFavorite = isFavorite
        modelContext.insert(task)

        // Sync favorites to widgets if this is a favorite task
        if isFavorite {
            timeTracker.syncFavoriteTasks(from: modelContext)
        }

        dismiss()
    }
}

struct TaskDetailView: View {
    @Bindable var task: TrackedTask
    @Environment(\.modelContext) private var modelContext
    @Environment(TimeTracker.self) private var timeTracker

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $task.name)
            }

            Section("Appearance") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                    ForEach(TaskColor.allCases, id: \.self) { color in
                        Button {
                            task.colorHex = color.rawValue
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if task.colorHex == color.rawValue {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .font(.headline)
                                    }
                                }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Toggle("Favorite", isOn: $task.isFavorite)
                Toggle("Archived", isOn: $task.isArchived)
            }

            Section("Pomodoro Timer") {
                PomodoroSettingsSection(task: task)
            }

            Section("Statistics") {
                HStack {
                    Text("Today")
                    Spacer()
                    Text(task.todayDuration.shortFormatted)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("This Week")
                    Spacer()
                    Text(task.weekDuration.shortFormatted)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Edit Task")
        .onChange(of: task.isFavorite) {
            timeTracker.syncFavoriteTasks(from: modelContext)
        }
        .onChange(of: task.isArchived) {
            timeTracker.syncFavoriteTasks(from: modelContext)
        }
    }
}

struct PomodoroSettingsSection: View {
    @Bindable var task: TrackedTask
    @Environment(\.modelContext) private var modelContext

    private var settings: PomodoroSettings {
        if let existing = task.pomodoroSettings {
            return existing
        } else {
            let newSettings = PomodoroSettings()
            newSettings.task = task
            modelContext.insert(newSettings)
            return newSettings
        }
    }

    var body: some View {
        @Bindable var pomodoroSettings = settings

        Toggle("Enable Pomodoro", isOn: $pomodoroSettings.isEnabled)

        if pomodoroSettings.isEnabled {
            Stepper("Work: \(pomodoroSettings.workDuration) min", value: $pomodoroSettings.workDuration, in: 5...60, step: 5)
            Stepper("Short Break: \(pomodoroSettings.shortBreakDuration) min", value: $pomodoroSettings.shortBreakDuration, in: 1...30)
            Stepper("Long Break: \(pomodoroSettings.longBreakDuration) min", value: $pomodoroSettings.longBreakDuration, in: 5...60, step: 5)
            Stepper("Sessions before long break: \(pomodoroSettings.sessionsBeforeLongBreak)", value: $pomodoroSettings.sessionsBeforeLongBreak, in: 2...8)
        }
    }
}

#Preview {
    let container = createPreviewModelContainer()
    return TaskListView()
        .modelContainer(container)
        .onAppear {
            populatePreviewData(in: container.mainContext)
        }
}
