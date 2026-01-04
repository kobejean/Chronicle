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
        }
    }

    private func configureServices() {
        // Configure location tracking
        timeTracker.configureLocation(
            service: locationService,
            geofence: geofenceManager,
            context: modelContext
        )

        // Configure geofence manager
        geofenceManager.configure(
            locationService: locationService,
            modelContext: modelContext
        )

        // Sync geofences on launch
        geofenceManager.syncGeofences()

        // Load active entry
        timeTracker.loadActiveEntry(from: modelContext)
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
