import Foundation
import SwiftData
import UserNotifications

/// iOS has no native "random time" notification trigger, so this generates
/// concrete occurrence dates for a rolling window and schedules each as a
/// one-shot calendar-trigger notification, regenerated on every app
/// foreground/launch.
///
/// Random times are deterministically seeded from (reminder id, day) rather
/// than freshly randomized on every call. Without that, "today's check-in is
/// around 3pm" would jitter on every app open, and regeneration couldn't tell
/// an already-scheduled occurrence from a new one — causing needless
/// cancel/reschedule churn against the 64-pending-notification cap.
@MainActor
enum RandomReminderScheduler {
    static let daysAhead = 5

    static func rescheduleAll(context: ModelContext) async {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.isEnabled && $0.triggerType == TriggerType.random }
        )
        guard let reminders = try? context.fetch(descriptor) else { return }
        for reminder in reminders {
            await reschedule(reminder)
        }
    }

    static func reschedule(_ reminder: Reminder) async {
        let desired = desiredOccurrences(for: reminder, daysAhead: daysAhead)
        let desiredSuffixes = Set(desired.map(\.dayKey))

        let pendingIDs = await NotificationManager.shared.pendingRequestIdentifiers(kind: "random", reminderID: reminder.id)
        let prefix = "random-\(reminder.id.uuidString)-"
        let pendingSuffixes = Set(pendingIDs.compactMap { id -> String? in
            guard id.hasPrefix(prefix) else { return nil }
            return String(id.dropFirst(prefix.count))
        })

        for occurrence in desired where !pendingSuffixes.contains(occurrence.dayKey) {
            NotificationManager.shared.scheduleRandomOccurrence(reminder, date: occurrence.date, dayKey: occurrence.dayKey)
        }

        // Prune occurrences that have rolled out of the window (e.g. stale
        // days from before the reminder's window/frequency changed).
        let staleSuffixes = pendingSuffixes.subtracting(desiredSuffixes)
        if !staleSuffixes.isEmpty {
            let idsToRemove = staleSuffixes.map { "\(prefix)\($0)" }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    /// Returns each occurrence's fire date and a stable identifier suffix
    /// ("yyyy-MM-dd-<index>") used both for scheduling and for diffing
    /// against already-pending requests.
    static func desiredOccurrences(
        for reminder: Reminder,
        from referenceDate: Date = .now,
        daysAhead: Int = daysAhead,
        calendar: Calendar = .current
    ) -> [(date: Date, dayKey: String)] {
        guard let frequency = reminder.randomFrequencyPerDay,
              let windowStart = reminder.randomWindowStartMinutes,
              let windowEnd = reminder.randomWindowEndMinutes,
              frequency > 0, windowEnd > windowStart else { return [] }

        var results: [(Date, String)] = []
        let today = calendar.startOfDay(for: referenceDate)

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayKey = dayKeyFormatter.string(from: day)
            var generator = SeededGenerator(seed: stableSeed("\(reminder.id.uuidString)|\(dayKey)"))

            var minutesUsed = Set<Int>()
            var attempts = 0
            while minutesUsed.count < frequency && attempts < frequency * 25 {
                attempts += 1
                minutesUsed.insert(Int.random(in: windowStart...windowEnd, using: &generator))
            }

            for (index, minute) in minutesUsed.sorted().enumerated() {
                guard let occurrence = calendar.date(byAdding: .minute, value: minute, to: day) else { continue }
                if occurrence < referenceDate { continue }
                results.append((occurrence, "\(dayKey)-\(index)"))
            }
        }
        return results
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    /// FNV-1a over UTF8 bytes. Deliberately not Swift's `Hashable`/`hashValue` —
    /// those are randomized per process launch and would break determinism.
    private static func stableSeed(_ string: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash == 0 ? 1 : hash
    }
}

/// Deterministic xorshift64 generator — not cryptographically secure, which
/// is fine for picking non-adversarial reminder times.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
