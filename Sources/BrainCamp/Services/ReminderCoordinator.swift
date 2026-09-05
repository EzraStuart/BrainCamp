import Foundation
import Combine
import SwiftData

/// The sole point where Views trigger scheduling/monitoring side effects, so
/// Views never import CoreLocation or UserNotifications directly.
@MainActor
final class ReminderCoordinator: ObservableObject {
    private let locationManager: LocationManager
    private let notificationManager = NotificationManager.shared

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    /// Call after creating, editing, enabling, or disabling a reminder.
    func reminderDidChange(_ reminder: Reminder) {
        notificationManager.cancel(reminderID: reminder.id)

        guard reminder.isEnabled, !reminder.isMisconfigured else {
            if reminder.triggerType == .location { locationManager.syncMonitoredRegions() }
            return
        }

        switch reminder.triggerType {
        case .oneTime:
            notificationManager.scheduleOneTime(reminder)
        case .recurring:
            notificationManager.scheduleRecurring(reminder)
        case .random:
            Task { await RandomReminderScheduler.reschedule(reminder) }
        case .location:
            locationManager.syncMonitoredRegions()
        }
    }

    func reminderWillDelete(_ reminder: Reminder) {
        notificationManager.cancel(reminderID: reminder.id)
        if reminder.triggerType == .location {
            locationManager.syncMonitoredRegions()
        }
    }

    /// Importance/place edits affect the 20-region priority ranking.
    func itemDidChange(_ item: Item) {
        if item.localReminders.contains(where: { $0.triggerType == .location }) {
            locationManager.syncMonitoredRegions()
        }
    }

    func placeDidChange(_ place: Place) {
        locationManager.syncMonitoredRegions()
    }

    func placeWillDelete(_ place: Place) {
        locationManager.syncMonitoredRegions()
    }

    func resyncEverything(context: ModelContext) async {
        locationManager.syncMonitoredRegions()
        await RandomReminderScheduler.rescheduleAll(context: context)
    }
}
