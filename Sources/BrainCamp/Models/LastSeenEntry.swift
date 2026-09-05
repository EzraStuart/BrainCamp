import Foundation
import SwiftData

/// Records where/when an item was actually confirmed to be — whether logged
/// manually by the user or captured automatically from a check-in
/// notification response or a geofence event.
@Model
final class LastSeenEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var item: Item?
    /// May differ from the item's designated place (e.g. "left it at work").
    var place: Place?
    /// Raw coordinate for an ad hoc "log at current location" entry that
    /// isn't tied to a reusable `Place` — avoids manufacturing a throwaway
    /// `Place` record for every one-off log.
    var latitude: Double?
    var longitude: Double?
    var source: LogSource
    var note: String?
    /// `.nullify` on delete so history survives even if the reminder that
    /// triggered it is later removed.
    var relatedReminder: Reminder?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        item: Item? = nil,
        place: Place? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        source: LogSource,
        note: String? = nil,
        relatedReminder: Reminder? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.item = item
        self.place = place
        self.latitude = latitude
        self.longitude = longitude
        self.source = source
        self.note = note
        self.relatedReminder = relatedReminder
    }

    var locationDescription: String {
        if let place { return place.name }
        if let latitude, let longitude {
            return String(format: "%.4f, %.4f", latitude, longitude)
        }
        return "Unknown location"
    }
}
