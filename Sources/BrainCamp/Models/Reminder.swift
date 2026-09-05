import Foundation
import SwiftData

/// A reminder's trigger-specific parameters are stored as flat, always-optional
/// properties (rather than an enum with associated values) so SwiftData's
/// `#Predicate`/`@Query` can filter and sort on them directly.
@Model
final class Reminder {
    @Attribute(.unique) var id: UUID
    var title: String
    var scope: ReminderScope
    var triggerType: TriggerType
    var notificationStyle: NotificationStyle
    var isEnabled: Bool
    var createdAt: Date

    /// True for a reminder that should turn itself off after firing once —
    /// e.g. a recurring "check for earrings" reminder you only want for one
    /// night out, not every day going forward.
    var isTransient: Bool

    /// nil when `scope == .global`.
    var item: Item?

    // MARK: Recurring trigger
    /// Sunday = 1 ... Saturday = 7 (`Weekday.rawValue`). Empty/nil = every day.
    var recurringWeekdays: [Int]?
    var recurringHour: Int?
    var recurringMinute: Int?

    // MARK: Location trigger
    /// `.nullify` on delete: a location reminder whose place was removed is
    /// treated as disabled/misconfigured until the user assigns a new place.
    @Relationship(deleteRule: .nullify)
    var place: Place?
    var geofenceEvent: GeofenceEvent?

    // MARK: One-time trigger
    var oneTimeDate: Date?

    // MARK: Random trigger
    var randomFrequencyPerDay: Int?
    var randomWindowStartMinutes: Int?
    var randomWindowEndMinutes: Int?

    init(
        id: UUID = UUID(),
        title: String,
        scope: ReminderScope,
        triggerType: TriggerType,
        notificationStyle: NotificationStyle = .plain,
        isEnabled: Bool = true,
        isTransient: Bool = false,
        createdAt: Date = .now,
        item: Item? = nil
    ) {
        self.id = id
        self.title = title
        self.scope = scope
        self.triggerType = triggerType
        self.notificationStyle = notificationStyle
        self.isEnabled = isEnabled
        self.isTransient = isTransient
        self.createdAt = createdAt
        self.item = item
    }

    var isMisconfigured: Bool {
        switch triggerType {
        case .location: return place == nil
        case .recurring: return recurringHour == nil || recurringMinute == nil
        case .oneTime: return oneTimeDate == nil
        case .random: return randomFrequencyPerDay == nil || randomWindowStartMinutes == nil || randomWindowEndMinutes == nil
        }
    }
}
