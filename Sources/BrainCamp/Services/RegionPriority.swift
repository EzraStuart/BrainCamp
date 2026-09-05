import Foundation

/// Pure ranking logic behind `LocationManager`'s 20-region-monitoring-limit
/// strategy, factored out so it's unit-testable without CoreLocation or
/// SwiftData: highest importance wins, then closest to the user, then most
/// recently created reminder as a stable tiebreaker.
enum RegionPriority {
    struct Candidate {
        let id: UUID
        let importance: Importance
        /// nil when the user's current location isn't known yet.
        let distanceMeters: Double?
        let mostRecentReminderDate: Date
    }

    static func rank(_ candidates: [Candidate]) -> [UUID] {
        candidates
            .sorted { lhs, rhs in
                if lhs.importance != rhs.importance {
                    return lhs.importance.rawValue > rhs.importance.rawValue
                }
                switch (lhs.distanceMeters, rhs.distanceMeters) {
                case let (l?, r?) where l != r:
                    return l < r
                case (nil, .some):
                    return false
                case (.some, nil):
                    return true
                default:
                    return lhs.mostRecentReminderDate > rhs.mostRecentReminderDate
                }
            }
            .map(\.id)
    }
}
