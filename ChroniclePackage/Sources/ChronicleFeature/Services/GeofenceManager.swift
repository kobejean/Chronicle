import Foundation
import SwiftData
import CoreLocation
import Observation
import UserNotifications

/// Manages geofencing for automatic task triggers when entering/exiting places
@Observable
@MainActor
public final class GeofenceManager {
    /// Whether geofencing is enabled globally
    public var isEnabled: Bool = true

    /// Reference to location service for geofence monitoring
    private weak var locationService: LocationService?

    /// Reference to task controller for starting/stopping tasks
    private weak var taskController: TaskController?

    /// Model context for database operations
    private var modelContext: ModelContext?

    /// Currently active geofence place ID (to track auto-started tasks)
    private var activeGeofencePlaceID: UUID?

    public init() {}

    /// Configure the manager with dependencies
    public func configure(
        locationService: LocationService,
        taskController: TaskController,
        modelContext: ModelContext
    ) {
        self.locationService = locationService
        self.taskController = taskController
        self.modelContext = modelContext

        // Set up geofence callbacks from LocationService
        locationService.onGeofenceEnter = { [weak self] regionID in
            Task { @MainActor in
                self?.handleGeofenceEnter(regionID: regionID)
            }
        }

        locationService.onGeofenceExit = { [weak self] regionID in
            Task { @MainActor in
                self?.handleGeofenceExit(regionID: regionID)
            }
        }
    }

    // MARK: - Geofence Management

    /// Sync all places with geofencing enabled
    public func syncGeofences() {
        guard let context = modelContext,
              let locationService = locationService,
              locationService.authorizationStatus.canUseGeofencing else {
            return
        }

        // Stop all current monitoring
        locationService.stopMonitoringAllRegions()

        guard isEnabled else { return }

        // Fetch all places with geofencing enabled
        let descriptor = FetchDescriptor<Place>(
            predicate: #Predicate { $0.isGeofenceEnabled }
        )

        guard let places = try? context.fetch(descriptor) else { return }

        // Start monitoring each place
        for place in places {
            locationService.startMonitoring(region: place.region)
        }
    }

    /// Start monitoring a specific place
    public func startMonitoring(place: Place) {
        guard let locationService = locationService,
              locationService.authorizationStatus.canUseGeofencing,
              isEnabled else {
            return
        }

        locationService.startMonitoring(region: place.region)
    }

    /// Stop monitoring a specific place
    public func stopMonitoring(place: Place) {
        locationService?.stopMonitoring(region: place.region)
    }

    // MARK: - Geofence Events

    private func handleGeofenceEnter(regionID: String) {
        guard isEnabled,
              let context = modelContext,
              let placeID = UUID(uuidString: regionID) else {
            return
        }

        // Find the place
        let descriptor = FetchDescriptor<Place>(
            predicate: #Predicate { $0.id == placeID }
        )

        guard let places = try? context.fetch(descriptor),
              let place = places.first,
              let taskID = place.autoStartTaskID else {
            return
        }

        // Start the task via protocol
        activeGeofencePlaceID = placeID
        taskController?.startTaskByID(taskID, in: context)

        // Send notification
        sendNotification(
            title: "Arrived at \(place.name)",
            body: "Time tracking started automatically"
        )
    }

    private func handleGeofenceExit(regionID: String) {
        guard isEnabled,
              let context = modelContext,
              let placeID = UUID(uuidString: regionID) else {
            return
        }

        // Only stop if this is the place that auto-started the current task
        guard activeGeofencePlaceID == placeID else { return }

        // Find the place
        let descriptor = FetchDescriptor<Place>(
            predicate: #Predicate { $0.id == placeID }
        )

        guard let places = try? context.fetch(descriptor),
              let place = places.first,
              place.autoStopOnExit else {
            return
        }

        // Stop the task via protocol
        activeGeofencePlaceID = nil
        taskController?.stopCurrentEntry(in: context)

        // Send notification
        sendNotification(
            title: "Left \(place.name)",
            body: "Time tracking stopped automatically"
        )
    }

    // MARK: - Notifications

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "geofence-\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }
}
