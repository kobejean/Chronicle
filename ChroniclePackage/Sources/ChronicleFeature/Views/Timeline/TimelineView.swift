import SwiftUI
import SwiftData

public struct TimelineView: View {
    @State private var selectedDate = Date()
    @Query private var timeEntries: [TimeEntry]

    private var entriesForSelectedDay: [TimeEntry] {
        let calendar = Calendar.current
        return timeEntries
            .filter { calendar.isDate($0.startTime, inSameDayAs: selectedDate) }
            .sorted { $0.startTime < $1.startTime }
    }

    private var totalDuration: TimeInterval {
        entriesForSelectedDay.reduce(0) { $0 + $1.duration }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date picker
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)

                Divider()

                // Summary bar
                HStack {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(totalDuration.shortFormatted)
                        .font(.headline)
                }
                .padding()

                // Timeline visualization
                TimelineBar(entries: entriesForSelectedDay)
                    .frame(height: 60)
                    .padding(.horizontal)

                Divider()
                    .padding(.vertical)

                // Entry list
                if entriesForSelectedDay.isEmpty {
                    ContentUnavailableView(
                        "No Activity",
                        systemImage: "clock",
                        description: Text("No time entries for this day")
                    )
                } else {
                    List(entriesForSelectedDay) { entry in
                        TimeEntryRow(entry: entry)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Timeline")
        }
    }

    public init() {}
}

struct TimelineBar: View {
    let entries: [TimeEntry]

    private let dayStart: Date = {
        Calendar.current.startOfDay(for: Date())
    }()

    private let totalMinutesInDay: Double = 24 * 60

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background with hour markers
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))

                // Hour markers
                ForEach([6, 12, 18], id: \.self) { hour in
                    let x = geometry.size.width * (Double(hour * 60) / totalMinutesInDay)
                    VStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1)
                        Text("\(hour)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .position(x: x, y: geometry.size.height / 2)
                }

                // Time entry blocks
                ForEach(entries) { entry in
                    TimeBlockView(entry: entry, geometry: geometry, dayStart: dayStart)
                }
            }
        }
    }
}

struct TimeBlockView: View {
    let entry: TimeEntry
    let geometry: GeometryProxy
    let dayStart: Date

    private var startOffset: Double {
        let minutesSinceDayStart = entry.startTime.timeIntervalSince(dayStart) / 60
        return max(0, minutesSinceDayStart) / (24 * 60)
    }

    private var widthRatio: Double {
        let durationMinutes = entry.duration / 60
        return durationMinutes / (24 * 60)
    }

    var body: some View {
        let x = geometry.size.width * startOffset
        let width = max(4, geometry.size.width * widthRatio)

        RoundedRectangle(cornerRadius: 4)
            .fill(entry.task?.color ?? .gray)
            .frame(width: width, height: geometry.size.height * 0.6)
            .offset(x: x)
    }
}

struct TimeEntryRow: View {
    let entry: TimeEntry

    private var hasGPSTrail: Bool {
        !(entry.gpsTrail ?? []).isEmpty
    }

    var body: some View {
        NavigationLink {
            TimeEntryDetailView(entry: entry)
        } label: {
            HStack {
                Circle()
                    .fill(entry.task?.color ?? .gray)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading) {
                    Text(entry.task?.name ?? "Unknown")
                        .font(.headline)

                    HStack(spacing: 8) {
                        Text(formatTimeRange())
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if hasGPSTrail {
                            Label("\((entry.gpsTrail ?? []).count)", systemImage: "location.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(entry.formattedDuration)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if entry.isRunning {
                        Text("Running")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let start = formatter.string(from: entry.startTime)
        if let endTime = entry.endTime {
            let end = formatter.string(from: endTime)
            return "\(start) - \(end)"
        } else {
            return "\(start) - now"
        }
    }
}

/// Detail view for a time entry with GPS trail
struct TimeEntryDetailView: View {
    let entry: TimeEntry

    private var hasGPSTrail: Bool {
        !(entry.gpsTrail ?? []).isEmpty
    }

    var body: some View {
        List {
            Section("Time") {
                LabeledContent("Task", value: entry.task?.name ?? "Unknown")
                LabeledContent("Start", value: formatTime(entry.startTime))
                if let endTime = entry.endTime {
                    LabeledContent("End", value: formatTime(endTime))
                }
                LabeledContent("Duration", value: entry.formattedDuration)
            }

            if hasGPSTrail {
                Section("Location") {
                    GPSTrailPreview(timeEntry: entry)
                }
            }

            if let notes = entry.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .navigationTitle(entry.task?.name ?? "Time Entry")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    let container = createPreviewModelContainer()
    return TimelineView()
        .modelContainer(container)
        .onAppear {
            populatePreviewData(in: container.mainContext)
        }
}
