import Foundation
import SwiftData
import CoreLocation

/// A single GPS coordinate point in a trail
@Model
public final class GPSPoint {
    public var id: UUID = UUID()
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    public var altitude: Double = 0.0
    public var horizontalAccuracy: Double = 0.0
    public var timestamp: Date = Date()
    public var speed: Double = 0.0

    public var timeEntry: TimeEntry? = nil

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double = 0,
        accuracy: Double = 0,
        speed: Double = 0
    ) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = accuracy
        self.speed = speed
        self.timestamp = Date()
    }

    public init(from location: CLLocation) {
        self.id = UUID()
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.speed = max(0, location.speed)
        self.timestamp = location.timestamp
    }

    /// CLLocationCoordinate2D for MapKit
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// CLLocation for distance calculations
    public var location: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }
}
