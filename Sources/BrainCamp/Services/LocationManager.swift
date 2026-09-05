import Foundation
import Combine
import CoreLocation
import SwiftData

/// Wraps CoreLocation region monitoring and implements the strategy for
/// iOS's hard cap of 20 simultaneously monitored regions per app: candidate
/// places (those referenced by an enabled location reminder) are ranked by
/// the importance of the item they protect, then by proximity to the user's
/// last known location, then by recency — and only the top 20 are actually
/// monitored. Re-ranking runs on launch/foreground/relevant edits and on
/// significant-location-change updates, so the monitored set follows the
/// user instead of permanently favoring whichever 20 places were created first.
@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let maxMonitoredRegions = 20

    private let manager = CLLocationManager()
    private var context: ModelContext { PersistenceController.mainContext }
    private var lastKnownLocation: CLLocation?
    private var oneTimeLocationCompletion: ((CLLocation?) -> Void)?

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var activelyMonitoredPlaceIDs: Set<UUID> = []
    @Published private(set) var totalCandidatePlaceCount: Int = 0

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    // MARK: - Permissions

    /// Two-step flow per Apple guidance: request When In Use first (call
    /// from onboarding), then request the Always upgrade once the user has
    /// seen the in-app rationale. Safe to call repeatedly.
    func requestWhenInUseThenAlways() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways {
            manager.startMonitoringSignificantLocationChanges()
            syncMonitoredRegions()
        }
    }

    // MARK: - One-time location (for "log at current location")

    func requestOneTimeLocation(completion: @escaping (CLLocation?) -> Void) {
        oneTimeLocationCompletion = completion
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnownLocation = locations.last
        if let completion = oneTimeLocationCompletion {
            oneTimeLocationCompletion = nil
            completion(locations.last)
        }
        syncMonitoredRegions()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let completion = oneTimeLocationCompletion {
            oneTimeLocationCompletion = nil
            completion(nil)
        }
    }

    // MARK: - Region sync

    func syncMonitoredRegions() {
        guard authorizationStatus == .authorizedAlways else { return }

        let reminders = fetchEnabledLocationReminders()
        let candidatePlaces = rankedCandidatePlaces(from: reminders)
        totalCandidatePlaceCount = candidatePlaces.count
        let topPlaces = Array(candidatePlaces.prefix(Self.maxMonitoredRegions))
        let desiredIDs = Set(topPlaces.map(\.id))

        for region in manager.monitoredRegions {
            guard let circular = region as? CLCircularRegion,
                  let uuid = UUID(uuidString: circular.identifier),
                  !desiredIDs.contains(uuid) else { continue }
            manager.stopMonitoring(for: circular)
        }

        let alreadyMonitored = Set(
            manager.monitoredRegions.compactMap { ($0 as? CLCircularRegion).flatMap { UUID(uuidString: $0.identifier) } }
        )
        for place in topPlaces where !alreadyMonitored.contains(place.id) {
            manager.startMonitoring(for: place.region)
        }

        activelyMonitoredPlaceIDs = desiredIDs
    }

    private func fetchEnabledLocationReminders() -> [Reminder] {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.isEnabled && $0.triggerType == TriggerType.location }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Builds candidates and delegates the actual ordering to `RegionPriority`
    /// (a pure function, unit-tested separately).
    private func rankedCandidatePlaces(from reminders: [Reminder]) -> [Place] {
        var bestImportance: [UUID: Importance] = [:]
        var placesByID: [UUID: Place] = [:]
        var mostRecentReminderDate: [UUID: Date] = [:]

        for reminder in reminders {
            guard let place = reminder.place else { continue }
            placesByID[place.id] = place
            let importance = reminder.item?.importance ?? .medium
            if bestImportance[place.id].map({ importance.rawValue > $0.rawValue }) ?? true {
                bestImportance[place.id] = importance
            }
            if mostRecentReminderDate[place.id].map({ reminder.createdAt > $0 }) ?? true {
                mostRecentReminderDate[place.id] = reminder.createdAt
            }
        }

        let candidates = placesByID.values.map { place -> RegionPriority.Candidate in
            let distance = lastKnownLocation.map {
                $0.distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
            }
            return RegionPriority.Candidate(
                id: place.id,
                importance: bestImportance[place.id] ?? .low,
                distanceMeters: distance,
                mostRecentReminderDate: mostRecentReminderDate[place.id] ?? .distantPast
            )
        }

        let orderedIDs = RegionPriority.rank(candidates)
        return orderedIDs.compactMap { placesByID[$0] }
    }

    // MARK: - Region events

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        handleRegionEvent(region, event: .enter)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        handleRegionEvent(region, event: .exit)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        guard let id = region?.identifier, let uuid = UUID(uuidString: id) else { return }
        activelyMonitoredPlaceIDs.remove(uuid)
        syncMonitoredRegions()
    }

    private func handleRegionEvent(_ region: CLRegion, event: GeofenceEvent) {
        guard let placeID = UUID(uuidString: region.identifier) else { return }

        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.isEnabled && $0.triggerType == TriggerType.location }
        )
        guard let reminders = try? context.fetch(descriptor) else { return }

        let matching = reminders.filter { reminder in
            guard reminder.place?.id == placeID else { return false }
            switch reminder.geofenceEvent {
            case .enter: return event == .enter
            case .exit: return event == .exit
            case .both, .none: return true
            }
        }

        for reminder in matching {
            NotificationManager.shared.fireImmediateCheckIn(for: reminder, event: event)

            let entry = LastSeenEntry(
                item: reminder.item,
                place: reminder.place,
                source: event == .enter ? .locationArrival : .locationDeparture,
                relatedReminder: reminder
            )
            context.insert(entry)

            // Transient reminders self-disable after their first trigger —
            // e.g. a one-off "check for earrings tonight" reminder.
            if reminder.isTransient {
                reminder.isEnabled = false
            }
        }

        try? context.save()
        syncMonitoredRegions()
    }
}
