import SwiftUI
import SwiftData

public struct GoalsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [Goal]
    @Query private var streaks: [Streak]
    @Query(filter: #Predicate<TrackedTask> { !$0.isArchived }) private var tasks: [TrackedTask]
    @State private var showingAddGoal = false

    private var activeGoals: [Goal] {
        goals.filter { $0.isActive }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Daily Summary
                    DailySummaryCard(tasks: tasks)

                    // Active Goals
                    if !activeGoals.isEmpty {
                        GoalsSection(goals: activeGoals)
                    }

                    // Streaks
                    if !streaks.isEmpty {
                        StreaksSection(streaks: streaks)
                    }

                    // Empty state
                    if activeGoals.isEmpty && streaks.isEmpty {
                        ContentUnavailableView(
                            "No Goals Set",
                            systemImage: "target",
                            description: Text("Add goals to track your progress")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalSheet(tasks: tasks)
            }
        }
    }

    public init() {}
}

struct DailySummaryCard: View {
    let tasks: [TrackedTask]

    private var totalToday: TimeInterval {
        tasks.reduce(0) { $0 + $1.todayDuration }
    }

    private var tasksWorkedToday: Int {
        tasks.filter { $0.todayDuration > 0 }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Today's Summary")
                .font(.headline)

            HStack(spacing: 32) {
                VStack {
                    Text(totalToday.shortFormatted)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Total Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    Text("\(tasksWorkedToday)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct GoalsSection: View {
    let goals: [Goal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goals")
                .font(.headline)

            ForEach(goals) { goal in
                GoalProgressRow(goal: goal)
            }
        }
    }
}

struct GoalProgressRow: View {
    let goal: Goal

    private var trackedDuration: TimeInterval {
        guard let task = goal.task else { return 0 }
        return goal.goalType == .daily ? task.todayDuration : task.weekDuration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(goal.task?.color ?? .gray)
                    .frame(width: 8, height: 8)

                Text(goal.task?.name ?? "Unknown")
                    .font(.subheadline)

                Text(goal.goalType == .daily ? "Daily" : "Weekly")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2), in: Capsule())

                Spacer()

                if goal.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(goal.task?.color ?? .blue)
                        .frame(width: geometry.size.width * min(goal.progress, 1.0))
                }
            }
            .frame(height: 8)

            HStack {
                Text(trackedDuration.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("/")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text(goal.targetDuration.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(goal.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct StreaksSection: View {
    let streaks: [Streak]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streaks")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(streaks) { streak in
                    StreakCard(streak: streak)
                }
            }
        }
    }
}

struct StreakCard: View {
    let streak: Streak

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: streak.isActive ? "flame.fill" : "flame")
                .font(.title)
                .foregroundStyle(streak.isActive ? .orange : .gray)

            Text("\(streak.currentStreak)")
                .font(.title2)
                .fontWeight(.bold)

            Text("days")
                .font(.caption)
                .foregroundStyle(.secondary)

            if streak.longestStreak > streak.currentStreak {
                Text("Best: \(streak.longestStreak)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct AddGoalSheet: View {
    let tasks: [TrackedTask]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTask: TrackedTask?
    @State private var targetMinutes = 60
    @State private var goalType: Goal.GoalType = .daily

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    Picker("Task", selection: $selectedTask) {
                        Text("Select a task").tag(nil as TrackedTask?)
                        ForEach(tasks) { task in
                            HStack {
                                Circle()
                                    .fill(task.color)
                                    .frame(width: 8, height: 8)
                                Text(task.name)
                            }
                            .tag(task as TrackedTask?)
                        }
                    }
                }

                Section("Target") {
                    Picker("Goal Type", selection: $goalType) {
                        Text("Daily").tag(Goal.GoalType.daily)
                        Text("Weekly").tag(Goal.GoalType.weekly)
                    }
                    .pickerStyle(.segmented)

                    Stepper("\(targetMinutes) minutes", value: $targetMinutes, in: 15...480, step: 15)

                    Text("That's \(TimeInterval(targetMinutes * 60).shortFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addGoal()
                    }
                    .disabled(selectedTask == nil)
                }
            }
        }
    }

    private func addGoal() {
        guard let task = selectedTask else { return }
        let goal = Goal(task: task, targetMinutes: targetMinutes, goalType: goalType)
        modelContext.insert(goal)
        dismiss()
    }
}

#Preview {
    let container = createPreviewModelContainer()
    return GoalsDashboardView()
        .modelContainer(container)
        .onAppear {
            populatePreviewData(in: container.mainContext)
        }
}
