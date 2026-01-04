import SwiftUI
import SwiftData

public struct DiaryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var entries: [DiaryEntry]
    @State private var showingAddEntry = false

    public var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Diary Entries",
                        systemImage: "book",
                        description: Text("Tap + to add your first entry")
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink(destination: DiaryEntryDetailView(entry: entry)) {
                                DiaryEntryRow(entry: entry)
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .navigationTitle("Diary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddDiaryEntrySheet()
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }

    public init() {}
}

struct DiaryEntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(entry.moodEmoji)
                Text(entry.energyEmoji)
            }

            Text(entry.content)
                .lineLimit(2)

            if let task = entry.task {
                HStack {
                    Circle()
                        .fill(task.color)
                        .frame(width: 8, height: 8)
                    Text(task.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddDiaryEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<TrackedTask> { !$0.isArchived }) private var tasks: [TrackedTask]

    @State private var content = ""
    @State private var moodLevel = 3
    @State private var energyLevel = 3
    @State private var selectedTask: TrackedTask?

    var body: some View {
        NavigationStack {
            Form {
                Section("How are you feeling?") {
                    HStack {
                        Text("Mood")
                        Spacer()
                        MoodPicker(level: $moodLevel)
                    }

                    HStack {
                        Text("Energy")
                        Spacer()
                        EnergyPicker(level: $energyLevel)
                    }
                }

                Section("What's on your mind?") {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }

                Section("Related Task (Optional)") {
                    Picker("Task", selection: $selectedTask) {
                        Text("None").tag(nil as TrackedTask?)
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
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(content.isEmpty)
                }
            }
        }
    }

    private func saveEntry() {
        let entry = DiaryEntry(content: content, moodLevel: moodLevel, energyLevel: energyLevel)
        entry.task = selectedTask
        modelContext.insert(entry)
        dismiss()
    }
}

struct MoodPicker: View {
    @Binding var level: Int

    private let moods = ["😢", "😕", "😐", "🙂", "😄"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    level = value
                } label: {
                    Text(moods[value - 1])
                        .font(.title2)
                        .opacity(level == value ? 1.0 : 0.3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct EnergyPicker: View {
    @Binding var level: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    level = value
                } label: {
                    Image(systemName: value <= level ? "bolt.fill" : "bolt")
                        .foregroundStyle(value <= level ? .yellow : .gray)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DiaryEntryDetailView: View {
    @Bindable var entry: DiaryEntry

    var body: some View {
        Form {
            Section("Mood & Energy") {
                HStack {
                    Text("Mood")
                    Spacer()
                    MoodPicker(level: $entry.moodLevel)
                }

                HStack {
                    Text("Energy")
                    Spacer()
                    EnergyPicker(level: $entry.energyLevel)
                }
            }

            Section("Entry") {
                TextEditor(text: $entry.content)
                    .frame(minHeight: 150)
            }

            Section {
                HStack {
                    Text("Created")
                    Spacer()
                    Text(entry.createdAt, style: .date)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Modified")
                    Spacer()
                    Text(entry.modifiedAt, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Entry")
        .onChange(of: entry.content) {
            entry.modifiedAt = Date()
        }
    }
}

#Preview {
    let container = createPreviewModelContainer()
    return DiaryListView()
        .modelContainer(container)
}
