import SwiftUI
import MapKit
import CoreLocation

/// Lets the user drop a pin (tap, search, or start from an existing place)
/// and size a geofence radius around it. Used both when giving an item a
/// designated place and when defining a location-trigger reminder.
struct PlacePickerMapView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var coordinate: CLLocationCoordinate2D
    @State private var radiusMeters: Double
    @State private var name: String
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var cameraPosition: MapCameraPosition

    private let maxRadius = min(2000, CLLocationManager.maximumRegionMonitoringDistance)
    let existingPlace: Place?
    let onSave: (_ name: String, _ coordinate: CLLocationCoordinate2D, _ radiusMeters: Double) -> Void

    init(
        existingPlace: Place? = nil,
        onSave: @escaping (_ name: String, _ coordinate: CLLocationCoordinate2D, _ radiusMeters: Double) -> Void
    ) {
        self.existingPlace = existingPlace
        self.onSave = onSave
        let initialCoordinate = existingPlace?.coordinate ?? CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
        _coordinate = State(initialValue: initialCoordinate)
        _radiusMeters = State(initialValue: existingPlace?.radiusMeters ?? 100)
        _name = State(initialValue: existingPlace?.name ?? "")
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(center: initialCoordinate, latitudinalMeters: 800, longitudinalMeters: 800)
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        Marker(name.isEmpty ? "New place" : name, coordinate: coordinate)
                        MapCircle(center: coordinate, radius: radiusMeters)
                            .foregroundStyle(.blue.opacity(0.15))
                            .stroke(.blue, lineWidth: 2)
                    }
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            if let tapped = proxy.convert(value.location, from: .local) {
                                coordinate = tapped
                            }
                        }
                    )
                }
                .frame(height: 320)

                Form {
                    Section("Name") {
                        TextField("e.g. Home, Desk, Office", text: $name)
                    }
                    Section("Geofence radius: \(Int(radiusMeters))m") {
                        Slider(value: $radiusMeters, in: 25...maxRadius, step: 25)
                        Text("Notifications fire when you cross this boundary around the pin.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("Search") {
                        TextField("Search for a place", text: $searchText)
                            .onSubmit(runSearch)
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                select(item)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(item.name ?? "Unknown place")
                                    if let title = item.placemark.title {
                                        Text(title).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingPlace == nil ? "New Place" : "Edit Place")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.isEmpty ? "Untitled place" : name, coordinate, radiusMeters)
                        dismiss()
                    }
                }
            }
        }
    }

    private func runSearch() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 20_000, longitudinalMeters: 20_000)
        MKLocalSearch(request: request).start { response, _ in
            searchResults = response?.mapItems ?? []
        }
    }

    private func select(_ item: MKMapItem) {
        coordinate = item.placemark.coordinate
        if name.isEmpty { name = item.name ?? name }
        cameraPosition = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
        searchResults = []
        searchText = ""
    }
}
