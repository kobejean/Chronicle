import SwiftUI
import SwiftData

public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var timeTracker = TimeTracker()
    @State private var locationService = LocationService()
    @State private var geofenceManager = GeofenceManager()

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

            PlaceListView()
                .tabItem {
                    Label("Places", systemImage: "mappin")
                }
                .tag(3)

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
                .tag(4)
        }
        .environment(timeTracker)
        .environment(locationService)
        .environment(geofenceManager)
        .task {
            configureServices()
            processPendingWidgetActions()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            processPendingWidgetActions()
        }
    }

    private func configureServices() {
        // Configure location tracking for GPS trails
        timeTracker.configureLocation(
            service: locationService,
            context: modelContext
        )

        // Configure geofence manager with TimeTracker as task controller
        geofenceManager.configure(
            locationService: locationService,
            taskController: timeTracker,
            modelContext: modelContext
        )

        // Sync geofences on launch
        geofenceManager.syncGeofences()

        // Load active entry and sync widgets
        timeTracker.loadActiveEntry(from: modelContext)
        timeTracker.syncFavoriteTasks(from: modelContext)
    }

    private func processPendingWidgetActions() {
        guard let action = WidgetDataProvider.shared.getPendingAction() else { return }

        switch action {
        case .start(let taskId):
            guard let uuid = UUID(uuidString: taskId) else { break }
            timeTracker.startTaskByID(uuid, in: modelContext)
        case .stop(let taskId):
            if timeTracker.activeEntry?.task?.id.uuidString == taskId {
                timeTracker.stopCurrentEntry(in: modelContext)
            }
        }

        WidgetDataProvider.shared.clearPendingAction()
    }

    public init() {}
}

/// More tab containing additional features
struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DiaryListView()
                    } label: {
                        Label("Diary", systemImage: "book")
                    }

                    NavigationLink {
                        GoalsDashboardView()
                    } label: {
                        Label("Goals", systemImage: "target")
                    }
                }

                Section("Settings") {
                    NavigationLink {
                        LocationSettingsView()
                    } label: {
                        Label("Location", systemImage: "location")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(createPreviewModelContainer())
}
