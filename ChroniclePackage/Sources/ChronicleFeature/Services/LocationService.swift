import Foundation
import CoreLocation
import Observation
import UIKit

/// Accuracy mode for GPS tracking - balances battery usage vs precision
public enum LocationAccuracyMode: String, CaseIterable, Sendable {
    case high       // Best for GPS trails, ~10m accuracy
    case balanced   // Good accuracy with reasonable battery
    case low        // Battery saver, ~100m accuracy

    var desiredAccuracy: CLLocationAccuracy {
        switch self {
        case .high: return kCLLocationAccuracyBest
        case .balanced: return kCLLocationAccuracyNearestTenMeters
        case .low: return kCLLocationAccuracyHundredMeters
        }
    }

    var distanceFilter: CLLocationDistance {
        switch self {
        case .high: return 5      // Update every 5 meters
        case .balanced: return 25 // Update every 25 meters
        case .low: return 100     // Update every 100 meters
        }
    }

    var displayName: String {
        switch self {
        case .high: return "High Accuracy"
        case .balanced: return "Balanced"
        case .low: return "Battery Saver"
        }
    }

    var description: String {
        switch self {
        case .high: return "Best for detailed GPS trails"
        case .balanced: return "Good accuracy, moderate battery use"
        case .low: return "Minimal battery impact"
        }
    }
}

/// Authorization status for location services
public enum LocationAuthorizationStatus: Sendable {
    case notDetermined
    case denied
    case authorizedWhenInUse
    case authorizedAlways

    init(from status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied, .restricted:
            self = .denied
        case .authorizedWhenInUse:
            self = .authorizedWhenInUse
        case .authorizedAlways:
            self = .authorizedAlways
        @unknown default:
            self = .denied
        }
    }

    var canTrackLocation: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined, .denied:
            return false
        }
    }

    var canUseGeofencing: Bool {
        self == .authorizedAlways
    }
}

/// Core location service using CoreLocation for GPS tracking
@Observable
@MainActor
public final class LocationService: NSObject, Sendable {
    /// Current authorization status
    public private(set) var authorizationStatus: LocationAuthorizationStatus = .notDetermined

    /// Whether location tracking is currently active
    public private(set) var isTracking: Bool = false

    /// Current accuracy mode
    public var accuracyMode: LocationAccuracyMode = .balanced {
        didSet {
            if isTracking {
                updateLocationManagerSettings()
            }
        }
    }

    /// Most recent location
    public private(set) var currentLocation: CLLocation?

    /// Error message if any
    public private(set) var errorMessage: String?

    /// Callback when new location is received
    public var onLocationUpdate: ((CLLocation) -> Void)?

    /// Callback when entering a geofence region
    public var onGeofenceEnter: ((String) -> Void)?

    /// Callback when exiting a geofence region
    public var onGeofenceExit: ((String) -> Void)?

    private let locationManager: CLLocationManager

    public override init() {
        self.locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Request when-in-use authorization
    public func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Request always authorization (required for geofencing)
    public func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    /// Open system settings for the app
    public func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func updateAuthorizationStatus() {
        authorizationStatus = LocationAuthorizationStatus(from: locationManager.authorizationStatus)
    }

    // MARK: - Location Tracking

    /// Start tracking location
    public func startTracking() {
        guard authorizationStatus.canTrackLocation else {
            errorMessage = "Location permission required"
            return
        }

        updateLocationManagerSettings()
        locationManager.startUpdatingLocation()
        isTracking = true
        errorMessage = nil
    }

    /// Stop tracking location
    public func stopTracking() {
        locationManager.stopUpdatingLocation()
        isTracking = false
    }

    private func updateLocationManagerSettings() {
        locationManager.desiredAccuracy = accuracyMode.desiredAccuracy
        locationManager.distanceFilter = accuracyMode.distanceFilter
    }

    // MARK: - Geofencing

    /// Start monitoring a geofence region
    public func startMonitoring(region: CLCircularRegion) {
        guard authorizationStatus.canUseGeofencing else {
            errorMessage = "Always authorization required for geofencing"
            return
        }

        region.notifyOnEntry = true
        region.notifyOnExit = true
        locationManager.startMonitoring(for: region)
    }

    /// Stop monitoring a geofence region
    public func stopMonitoring(region: CLCircularRegion) {
        locationManager.stopMonitoring(for: region)
    }

    /// Stop monitoring all geofence regions
    public func stopMonitoringAllRegions() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }

    /// Get currently monitored regions
    public var monitoredRegions: Set<CLRegion> {
        locationManager.monitoredRegions
    }

    // MARK: - Single Location Request

    /// Request a single location update
    public func requestCurrentLocation() async throws -> CLLocation {
        guard authorizationStatus.canTrackLocation else {
            throw LocationError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let previousCallback = onLocationUpdate

            onLocationUpdate = { [weak self] location in
                guard !didResume else { return }
                didResume = true
                self?.onLocationUpdate = previousCallback
                if !self!.isTracking {
                    self?.locationManager.stopUpdatingLocation()
                }
                continuation.resume(returning: location)
            }

            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAuthorizationStatus()
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            currentLocation = location
            onLocationUpdate?(location)
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let identifier = region.identifier
        Task { @MainActor in
            onGeofenceEnter?(identifier)
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let identifier = region.identifier
        Task { @MainActor in
            onGeofenceExit?(identifier)
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            errorMessage = "Geofence monitoring failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Errors

public enum LocationError: Error, LocalizedError {
    case notAuthorized
    case locationUnavailable

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location permission not granted"
        case .locationUnavailable:
            return "Unable to determine location"
        }
    }
}
