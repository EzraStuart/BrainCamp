import Foundation
import SwiftData

@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String?
    var importance: Importance
    var iconSystemName: String?
    var createdAt: Date

    /// `.nullify` on delete: deleting a Place detaches items rather than
    /// deleting them; the UI flags a designated-place-less item.
    var designatedPlace: Place?

    @Relationship(deleteRule: .cascade, inverse: \Reminder.item)
    var localReminders: [Reminder] = []

    @Relationship(deleteRule: .cascade, inverse: \LastSeenEntry.item)
    var lastSeenEntries: [LastSeenEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        importance: Importance = .medium,
        iconSystemName: String? = nil,
        createdAt: Date = .now,
        designatedPlace: Place? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.importance = importance
        self.iconSystemName = iconSystemName
        self.createdAt = createdAt
        self.designatedPlace = designatedPlace
    }

    var mostRecentLastSeen: LastSeenEntry? {
        lastSeenEntries.max(by: { $0.timestamp < $1.timestamp })
    }
}
