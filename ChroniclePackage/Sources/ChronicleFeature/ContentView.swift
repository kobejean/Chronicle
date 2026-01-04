import SwiftUI
import SwiftData

public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var timeTracker = TimeTracker()

    public var body: some View {
        TabView(selection: $selectedTab) {
            TimerHomeView()
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
                .tag(0)

            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar.day.timeline.left")
                }
                .tag(1)

            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }
                .tag(2)

            DiaryListView()
                .tabItem {
                    Label("Diary", systemImage: "book")
                }
                .tag(3)

            GoalsDashboardView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(4)
        }
        .environment(timeTracker)
        .task {
            // Load active entry and sync widgets on app launch
            timeTracker.loadActiveEntry(from: modelContext)
            timeTracker.syncFavoriteTasks(from: modelContext)
        }
    }

    public init() {}
}

#Preview {
    ContentView()
        .modelContainer(createPreviewModelContainer())
}
