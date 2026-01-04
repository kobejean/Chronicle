import SwiftUI
import SwiftData
import ChronicleFeature

@main
struct ChronicleApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try createChronicleModelContainer()
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
