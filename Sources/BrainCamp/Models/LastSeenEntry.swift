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
    /// May differ from the item's designated place (e.g. "left it at work" ).
    var place: Place?
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
        source: LogSource,
        note: String? = nil,
        relatedReminder: Reminder? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.item = item
        self.place = place
        self.source = source
        self.note = note
        self.relatedReminder = relatedReminder
    }
}
