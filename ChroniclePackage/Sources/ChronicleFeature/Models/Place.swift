import Foundation
import SwiftData
import CoreLocation

/// A saved location that can trigger automatic task tracking
@Model
public final class Place {
    public var id: UUID = UUID()
    public var name: String = ""
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0

    /// Radius for geofence in meters
    public var radius: Double = 100.0

    /// Whether geofencing is enabled for this place
    public var isGeofenceEnabled: Bool = false

    /// Task ID to auto-start when entering this place
    public var autoStartTaskID: UUID? = nil

    /// Whether to auto-stop the task when leaving
    public var autoStopOnExit: Bool = true

    public var createdAt: Date = Date()

    @Relationship(inverse: \TimeEntry.place)
    public var timeEntries: [TimeEntry]? = []

    public init(name: String, latitude: Double, longitude: Double) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
    }

    /// CLLocationCoordinate2D for MapKit
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// CLCircularRegion for geofencing
    public var region: CLCircularRegion {
        CLCircularRegion(
            center: coordinate,
            radius: radius,
            identifier: id.uuidString
        )
    }
}
