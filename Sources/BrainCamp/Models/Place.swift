import Foundation
import SwiftData
import CoreLocation

@Model
final class Place {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    /// Geofence radius in meters. Clamped in the UI to
    /// `CLLocationManager.maximumRegionMonitoringDistance`.
    var radiusMeters: Double
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Item.designatedPlace)
    var items: [Item] = []

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 100,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.createdAt = createdAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// The identifier is the Place's own UUID so region-entry/exit callbacks
    /// can map straight back to a `Place` without a separate lookup table.
    var region: CLCircularRegion {
        let region = CLCircularRegion(center: coordinate, radius: radiusMeters, identifier: id.uuidString)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }
}
