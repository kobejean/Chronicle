import SwiftUI
import SwiftData
import MapKit

/// Map view displaying a GPS trail for a time entry
@MainActor
public struct GPSTrailMapView: View {
    let timeEntry: TimeEntry

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPoint: GPSPoint?

    public init(timeEntry: TimeEntry) {
        self.timeEntry = timeEntry
    }

    private var trailPoints: [GPSPoint] {
        (timeEntry.gpsTrail ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    private var trailCoordinates: [CLLocationCoordinate2D] {
        trailPoints.map { $0.coordinate }
    }

    private var totalDistance: CLLocationDistance {
        guard trailPoints.count > 1 else { return 0 }
        var distance: CLLocationDistance = 0
        for i in 1..<trailPoints.count {
            distance += trailPoints[i-1].location.distance(from: trailPoints[i].location)
        }
        return distance
    }

    public var body: some View {
        VStack(spacing: 0) {
            if trailPoints.isEmpty {
                emptyState
            } else {
                mapContent
                trailStats
            }
        }
        .navigationTitle("GPS Trail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No GPS Data", systemImage: "location.slash")
        } description: {
            Text("This time entry doesn't have GPS trail data. Enable GPS tracking to record your location while tracking time.")
        }
    }

    private var mapContent: some View {
        Map(position: $cameraPosition, selection: $selectedPoint) {
            // Trail polyline
            if trailCoordinates.count > 1 {
                MapPolyline(coordinates: trailCoordinates)
                    .stroke(.blue, lineWidth: 4)
            }

            // Start marker
            if let first = trailPoints.first {
                Annotation("Start", coordinate: first.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 24, height: 24)
                        Image(systemName: "play.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                }
            }

            // End marker
            if let last = trailPoints.last, trailPoints.count > 1 {
                Annotation("End", coordinate: last.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 24, height: 24)
                        Image(systemName: "stop.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                }
            }

            // Intermediate points
            ForEach(trailPoints.dropFirst().dropLast()) { point in
                Marker("", coordinate: point.coordinate)
                    .tint(.blue.opacity(0.6))
                    .tag(point)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
        .onAppear {
            fitMapToTrail()
        }
    }

    private var trailStats: some View {
        HStack(spacing: 24) {
            statItem(
                title: "Distance",
                value: formatDistance(totalDistance),
                icon: "ruler"
            )

            statItem(
                title: "Points",
                value: "\(trailPoints.count)",
                icon: "mappin"
            )

            statItem(
                title: "Duration",
                value: timeEntry.formattedDuration,
                icon: "clock"
            )

            if let avgSpeed = averageSpeed {
                statItem(
                    title: "Avg Speed",
                    value: formatSpeed(avgSpeed),
                    icon: "speedometer"
                )
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var averageSpeed: Double? {
        let speeds = trailPoints.map { $0.speed }.filter { $0 > 0 }
        guard !speeds.isEmpty else { return nil }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }

    private func formatSpeed(_ metersPerSecond: Double) -> String {
        let kmh = metersPerSecond * 3.6
        return String(format: "%.1f km/h", kmh)
    }

    private func fitMapToTrail() {
        guard !trailCoordinates.isEmpty else { return }

        let latitudes = trailCoordinates.map { $0.latitude }
        let longitudes = trailCoordinates.map { $0.longitude }

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5 + 0.002,
            longitudeDelta: (maxLon - minLon) * 1.5 + 0.002
        )

        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

/// Compact trail preview for use in lists
@MainActor
public struct GPSTrailPreview: View {
    let timeEntry: TimeEntry

    private var trailCoordinates: [CLLocationCoordinate2D] {
        (timeEntry.gpsTrail ?? [])
            .sorted { $0.timestamp < $1.timestamp }
            .map { $0.coordinate }
    }

    private var hasTrail: Bool {
        !trailCoordinates.isEmpty
    }

    public init(timeEntry: TimeEntry) {
        self.timeEntry = timeEntry
    }

    public var body: some View {
        if hasTrail {
            NavigationLink {
                GPSTrailMapView(timeEntry: timeEntry)
            } label: {
                HStack {
                    miniMap
                    trailInfo
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var miniMap: some View {
        Map(interactionModes: []) {
            if trailCoordinates.count > 1 {
                MapPolyline(coordinates: trailCoordinates)
                    .stroke(.blue, lineWidth: 2)
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var trailInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("GPS Trail")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("\(trailCoordinates.count) points")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Trail Map") {
    NavigationStack {
        GPSTrailMapView(timeEntry: previewTimeEntry())
    }
}

@MainActor
private func previewTimeEntry() -> TimeEntry {
    let entry = TimeEntry(task: nil)
    // Add some sample GPS points
    let baseCoord = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
    for i in 0..<20 {
        let point = GPSPoint(
            latitude: baseCoord.latitude + Double(i) * 0.0002,
            longitude: baseCoord.longitude + Double(i) * 0.0001,
            altitude: 10,
            accuracy: 5,
            speed: 1.5
        )
        if entry.gpsTrail == nil {
            entry.gpsTrail = []
        }
        entry.gpsTrail?.append(point)
    }
    return entry
}
