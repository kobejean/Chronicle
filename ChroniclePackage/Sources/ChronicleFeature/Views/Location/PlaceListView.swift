import SwiftUI
import SwiftData
import MapKit

/// List of saved places with geofencing options
@MainActor
public struct PlaceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var locationService
    @Environment(GeofenceManager.self) private var geofenceManager

    @Query(sort: \Place.name) private var places: [Place]

    @State private var showingAddPlace = false
    @State private var selectedPlace: Place?

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if places.isEmpty {
                    emptyState
                } else {
                    placesList
                }
            }
            .navigationTitle("Places")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddPlace = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlace) {
                AddPlaceView()
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailView(place: place)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Places", systemImage: "mappin.slash")
        } description: {
            Text("Add places to enable automatic task tracking when you arrive.")
        } actions: {
            Button("Add Place") {
                showingAddPlace = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var placesList: some View {
        List {
            ForEach(places) { place in
                PlaceRow(place: place)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPlace = place
                    }
            }
            .onDelete(perform: deletePlaces)
        }
    }

    private func deletePlaces(at offsets: IndexSet) {
        for index in offsets {
            let place = places[index]
            geofenceManager.stopMonitoring(place: place)
            modelContext.delete(place)
        }
        try? modelContext.save()
    }
}

/// Row displaying a single place
struct PlaceRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    if place.isGeofenceEnabled {
                        Label("Auto-start", systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(Int(place.radius))m radius")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if place.isGeofenceEnabled {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

/// View for adding a new place
@MainActor
struct AddPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var locationService

    @State private var name = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var radius: Double = 100
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Form {
                Section("Place Name") {
                    TextField("e.g., Office, Gym, Home", text: $name)
                }

                Section("Location") {
                    Map(position: $cameraPosition, interactionModes: [.all]) {
                        if let coordinate = selectedCoordinate {
                            Marker(name.isEmpty ? "New Place" : name, coordinate: coordinate)
                                .tint(.red)

                            MapCircle(center: coordinate, radius: radius)
                                .foregroundStyle(.blue.opacity(0.2))
                                .stroke(.blue, lineWidth: 2)
                        }
                    }
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { location in
                        // Note: This is a simplified approach.
                        // In production, you'd use a proper map interaction
                    }
                    .onAppear {
                        useCurrentLocation()
                    }

                    Button("Use Current Location") {
                        useCurrentLocation()
                    }
                }

                Section("Geofence Radius") {
                    VStack(alignment: .leading) {
                        Text("\(Int(radius)) meters")
                            .font(.headline)

                        Slider(value: $radius, in: 50...500, step: 25)
                    }
                }
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlace()
                    }
                    .disabled(name.isEmpty || selectedCoordinate == nil)
                }
            }
        }
    }

    private func useCurrentLocation() {
        if let location = locationService.currentLocation {
            selectedCoordinate = location.coordinate
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            ))
        } else {
            // Request location
            Task {
                if let location = try? await locationService.requestCurrentLocation() {
                    selectedCoordinate = location.coordinate
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        latitudinalMeters: 500,
                        longitudinalMeters: 500
                    ))
                }
            }
        }
    }

    private func savePlace() {
        guard let coordinate = selectedCoordinate else { return }

        let place = Place(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        place.radius = radius

        modelContext.insert(place)
        try? modelContext.save()

        dismiss()
    }
}

/// Detail view for editing a place
@MainActor
struct PlaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(GeofenceManager.self) private var geofenceManager

    @Bindable var place: Place

    @Query(
        filter: #Predicate<TrackedTask> { !$0.isArchived },
        sort: \TrackedTask.name
    ) private var tasks: [TrackedTask]

    @State private var selectedTaskID: UUID?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Form {
                Section("Place Name") {
                    TextField("Name", text: $place.name)
                }

                Section("Location") {
                    Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                        Marker(place.name, coordinate: place.coordinate)
                            .tint(.red)

                        MapCircle(center: place.coordinate, radius: place.radius)
                            .foregroundStyle(.blue.opacity(0.2))
                            .stroke(.blue, lineWidth: 2)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onAppear {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: place.coordinate,
                            latitudinalMeters: place.radius * 3,
                            longitudinalMeters: place.radius * 3
                        ))
                    }
                }

                Section("Geofence Radius") {
                    VStack(alignment: .leading) {
                        Text("\(Int(place.radius)) meters")
                            .font(.headline)

                        Slider(value: $place.radius, in: 50...500, step: 25)
                    }
                }

                Section("Automatic Tracking") {
                    Toggle("Enable Geofencing", isOn: $place.isGeofenceEnabled)
                        .onChange(of: place.isGeofenceEnabled) { _, isEnabled in
                            if isEnabled {
                                geofenceManager.startMonitoring(place: place)
                            } else {
                                geofenceManager.stopMonitoring(place: place)
                            }
                        }

                    if place.isGeofenceEnabled {
                        Picker("Auto-start Task", selection: $selectedTaskID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(tasks) { task in
                                Text(task.name).tag(task.id as UUID?)
                            }
                        }
                        .onChange(of: selectedTaskID) { _, newValue in
                            place.autoStartTaskID = newValue
                        }

                        Toggle("Auto-stop on Exit", isOn: $place.autoStopOnExit)
                    }
                }
            }
            .navigationTitle("Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedTaskID = place.autoStartTaskID
            }
        }
    }

    private func saveChanges() {
        try? modelContext.save()
        geofenceManager.syncGeofences()
    }
}

#Preview {
    PlaceListView()
        .modelContainer(createPreviewModelContainer())
        .environment(LocationService())
        .environment(GeofenceManager())
}
