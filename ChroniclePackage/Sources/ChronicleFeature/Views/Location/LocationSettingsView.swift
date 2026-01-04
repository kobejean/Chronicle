import SwiftUI

/// View for configuring location and GPS settings
@MainActor
public struct LocationSettingsView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(TimeTracker.self) private var timeTracker
    @Environment(GeofenceManager.self) private var geofenceManager

    public init() {}

    public var body: some View {
        Form {
            permissionSection
            gpsTrackingSection
            geofencingSection
            accuracySection
        }
        .navigationTitle("Location Settings")
    }

    private var permissionSection: some View {
        Section {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Location Permission")
                        .font(.headline)

                    Text(statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if locationService.authorizationStatus == .denied {
                    Button("Settings") {
                        locationService.openSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if locationService.authorizationStatus == .notDetermined {
                Button("Enable Location") {
                    locationService.requestWhenInUseAuthorization()
                }
                .buttonStyle(.borderedProminent)
            } else if locationService.authorizationStatus == .authorizedWhenInUse {
                Button("Enable Always-On (for Geofencing)") {
                    locationService.requestAlwaysAuthorization()
                }
                .buttonStyle(.bordered)
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Location permission is required for GPS trails and geofencing.")
        }
    }

    private var gpsTrackingSection: some View {
        Section {
            @Bindable var tracker = timeTracker

            Toggle("Record GPS Trails", isOn: $tracker.isGPSTrailEnabled)

            if timeTracker.isGPSTrailEnabled {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)

                    Text("GPS points will be recorded while tracking tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("GPS Trails")
        } footer: {
            Text("When enabled, your location is recorded while tracking time. This helps visualize where you spent your time on a map.")
        }
    }

    private var geofencingSection: some View {
        Section {
            @Bindable var geofence = geofenceManager

            Toggle("Enable Geofencing", isOn: $geofence.isEnabled)
                .disabled(!locationService.authorizationStatus.canUseGeofencing)

            if !locationService.authorizationStatus.canUseGeofencing {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)

                    Text("Requires 'Always' location permission")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink {
                PlaceListView()
            } label: {
                Label("Manage Places", systemImage: "mappin.and.ellipse")
            }
        } header: {
            Text("Automatic Tracking")
        } footer: {
            Text("Automatically start and stop task tracking when you arrive at or leave saved places.")
        }
    }

    private var accuracySection: some View {
        Section {
            @Bindable var service = locationService

            Picker("Accuracy Mode", selection: $service.accuracyMode) {
                ForEach(LocationAccuracyMode.allCases, id: \.self) { mode in
                    VStack(alignment: .leading) {
                        Text(mode.displayName)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(LocationAccuracyMode.allCases, id: \.self) { mode in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: mode == locationService.accuracyMode ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(mode == locationService.accuracyMode ? .blue : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.displayName)
                                .font(.subheadline)
                                .fontWeight(mode == locationService.accuracyMode ? .semibold : .regular)

                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        locationService.accuracyMode = mode
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Battery & Accuracy")
        } footer: {
            Text("Higher accuracy uses more battery but provides more detailed GPS trails.")
        }
    }

    private var statusIcon: String {
        switch locationService.authorizationStatus {
        case .notDetermined: return "questionmark.circle"
        case .denied: return "xmark.circle"
        case .authorizedWhenInUse: return "location"
        case .authorizedAlways: return "location.fill"
        }
    }

    private var statusColor: Color {
        switch locationService.authorizationStatus {
        case .notDetermined: return .orange
        case .denied: return .red
        case .authorizedWhenInUse: return .blue
        case .authorizedAlways: return .green
        }
    }

    private var statusDescription: String {
        switch locationService.authorizationStatus {
        case .notDetermined: return "Not configured"
        case .denied: return "Permission denied"
        case .authorizedWhenInUse: return "While using the app"
        case .authorizedAlways: return "Always allowed"
        }
    }
}

#Preview {
    NavigationStack {
        LocationSettingsView()
    }
    .environment(LocationService())
    .environment(TimeTracker())
    .environment(GeofenceManager())
}
