import Foundation
import Combine
import UserNotifications
import SwiftData

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private static let checkInCategoryID = "CHECK_IN"
    private static let plainCategoryID = "PLAIN"
    private static let yesActionID = "YES_HAVE_IT"
    private static let noActionID = "NO_MISSING"

    private let center = UNUserNotificationCenter.current()
    private var context: ModelContext { PersistenceController.mainContext }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    // MARK: - Setup

    private func registerCategories() {
        let yes = UNNotificationAction(identifier: Self.yesActionID, title: "Yes, I have it", options: [])
        let no = UNNotificationAction(identifier: Self.noActionID, title: "No, it's missing", options: [.foreground])
        let checkIn = UNNotificationCategory(identifier: Self.checkInCategoryID, actions: [yes, no], intentIdentifiers: [], options: [])
        let plain = UNNotificationCategory(identifier: Self.plainCategoryID, actions: [], intentIdentifiers: [], options: [])
        center.setNotificationCategories([checkIn, plain])
    }

    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        return granted
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    // MARK: - Identifiers
    // Convention: "<kind>-<reminderID>[-<suffix>]", enabling prefix-based lookup/cancellation.

    private func identifier(kind: String, reminderID: UUID, suffix: String? = nil) -> String {
        var id = "\(kind)-\(reminderID.uuidString)"
        if let suffix { id += "-\(suffix)" }
        return id
    }

    // MARK: - Content

    private func content(for reminder: Reminder, bodyOverride: String? = nil) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let itemName = reminder.item?.name
        content.title = itemName.map { "Don't forget: \($0)" } ?? reminder.title

        if let bodyOverride {
            content.body = bodyOverride
        } else if reminder.notificationStyle == .checkIn {
            let place = reminder.place?.name ?? reminder.item?.designatedPlace?.name
            content.body = place.map { "Do you have it? It should be at \($0)." } ?? "Do you have it? Is it where it belongs?"
        } else {
            content.body = reminder.title
        }

        content.sound = .default
        content.categoryIdentifier = reminder.notificationStyle == .checkIn ? Self.checkInCategoryID : Self.plainCategoryID

        var userInfo: [String: Any] = [
            "reminderID": reminder.id.uuidString,
            "style": reminder.notificationStyle.rawValue,
        ]
        if let itemID = reminder.item?.id.uuidString { userInfo["itemID"] = itemID }
        if let placeID = reminder.place?.id.uuidString { userInfo["placeID"] = placeID }
        content.userInfo = userInfo

        return content
    }

    // MARK: - Scheduling

    func scheduleOneTime(_ reminder: Reminder) {
        guard let date = reminder.oneTimeDate else { return }
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(kind: "oneTime", reminderID: reminder.id),
            content: content(for: reminder),
            trigger: trigger
        )
        center.add(request)
    }

    /// A single `UNCalendarNotificationTrigger` can't express "every Mon/Wed/Fri,"
    /// so one repeating request is scheduled per selected weekday. Each uses
    /// `repeats: true`, reusing one pending slot forever — cheap against the
    /// 64-pending-notification cap.
    func scheduleRecurring(_ reminder: Reminder) {
        guard let hour = reminder.recurringHour, let minute = reminder.recurringMinute else { return }
        let weekdays = (reminder.recurringWeekdays?.isEmpty ?? true) ? Array(1...7) : reminder.recurringWeekdays!
        for weekday in weekdays {
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            comps.weekday = weekday
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: identifier(kind: "recurring", reminderID: reminder.id, suffix: "wd\(weekday)"),
                content: content(for: reminder),
                trigger: trigger
            )
            center.add(request)
        }
    }

    /// Called by `RandomReminderScheduler` for each concretely-dated occurrence
    /// it generates within its rolling window.
    func scheduleRandomOccurrence(_ reminder: Reminder, date: Date, dayKey: String) {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(kind: "random", reminderID: reminder.id, suffix: dayKey),
            content: content(for: reminder),
            trigger: trigger
        )
        center.add(request)
    }

    /// Location-triggered notifications fire the moment CoreLocation reports
    /// entry/exit — event-driven, not pre-scheduled ahead of time.
    func fireImmediateCheckIn(for reminder: Reminder, event: GeofenceEvent) {
        let body: String? = reminder.notificationStyle == .checkIn
            ? (event == .enter ? "You've arrived. Do you have it with you?" : "You're leaving. Do you have it with you?")
            : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(kind: "location", reminderID: reminder.id, suffix: UUID().uuidString),
            content: content(for: reminder, bodyOverride: body),
            trigger: trigger
        )
        center.add(request)
    }

    func cancel(reminderID: UUID) {
        center.getPendingNotificationRequests { [center] requests in
            let ids = requests.map(\.identifier).filter { $0.contains(reminderID.uuidString) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func pendingRequestIdentifiers(kind: String, reminderID: UUID) async -> Set<String> {
        let requests = await center.pendingNotificationRequests()
        let wanted = "\(kind)-\(reminderID.uuidString)-"
        return Set(requests.map(\.identifier).filter { $0.hasPrefix(wanted) })
    }

    func pendingNotificationCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let reminderIDString = userInfo["reminderID"] as? String,
              let reminderID = UUID(uuidString: reminderIDString) else { return }

        let context = self.context
        let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate<Reminder> { $0.id == reminderID })
        guard let reminder = try? context.fetch(descriptor).first else { return }

        switch response.actionIdentifier {
        case Self.yesActionID:
            context.insert(LastSeenEntry(
                item: reminder.item,
                place: reminder.item?.designatedPlace,
                source: .checkInConfirmed,
                relatedReminder: reminder
            ))
        case Self.noActionID:
            context.insert(LastSeenEntry(
                item: reminder.item,
                place: nil,
                source: .checkInMissing,
                relatedReminder: reminder
            ))
        default:
            break
        }

        // Transient reminders self-disable after their first trigger —
        // e.g. a one-off "check for earrings tonight" reminder.
        if reminder.isTransient {
            reminder.isEnabled = false
        }

        try? context.save()
    }
}
