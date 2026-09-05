import XCTest
@testable import BrainCamp

@MainActor
final class RandomReminderSchedulerTests: XCTestCase {
    private func midnightToday() -> Date {
        Calendar.current.startOfDay(for: .now)
    }

    private func makeRandomReminder(title: String = "Check keys", frequency: Int, startMinutes: Int, endMinutes: Int) -> Reminder {
        let reminder = Reminder(title: title, scope: .global, triggerType: .random)
        reminder.randomFrequencyPerDay = frequency
        reminder.randomWindowStartMinutes = startMinutes
        reminder.randomWindowEndMinutes = endMinutes
        return reminder
    }

    func testOccurrenceCountMatchesFrequency() {
        let reminder = makeRandomReminder(frequency: 3, startMinutes: 9 * 60, endMinutes: 21 * 60)
        let occurrences = RandomReminderScheduler.desiredOccurrences(for: reminder, from: midnightToday(), daysAhead: 1)
        XCTAssertEqual(occurrences.count, 3)
    }

    func testOccurrencesAreDeterministicAcrossCalls() {
        let reminder = makeRandomReminder(frequency: 4, startMinutes: 8 * 60, endMinutes: 20 * 60)
        let reference = midnightToday()

        let first = RandomReminderScheduler.desiredOccurrences(for: reminder, from: reference, daysAhead: 3)
        let second = RandomReminderScheduler.desiredOccurrences(for: reminder, from: reference, daysAhead: 3)

        XCTAssertEqual(first.map(\.dayKey), second.map(\.dayKey))
        XCTAssertEqual(first.map(\.date), second.map(\.date))
    }

    func testOccurrencesFallWithinConfiguredWindow() {
        let reminder = makeRandomReminder(frequency: 5, startMinutes: 10 * 60, endMinutes: 12 * 60)
        let reference = midnightToday()
        let occurrences = RandomReminderScheduler.desiredOccurrences(for: reminder, from: reference, daysAhead: 2)

        let calendar = Calendar.current
        for occurrence in occurrences {
            let day = calendar.startOfDay(for: occurrence.date)
            let minutesSinceMidnight = calendar.dateComponents([.minute], from: day, to: occurrence.date).minute ?? -1
            XCTAssertGreaterThanOrEqual(minutesSinceMidnight, 10 * 60)
            XCTAssertLessThanOrEqual(minutesSinceMidnight, 12 * 60)
        }
    }

    func testDifferentRemindersProduceDifferentSchedules() {
        let reminderA = makeRandomReminder(title: "A", frequency: 2, startMinutes: 9 * 60, endMinutes: 21 * 60)
        let reminderB = makeRandomReminder(title: "B", frequency: 2, startMinutes: 9 * 60, endMinutes: 21 * 60)
        let reference = midnightToday()

        let occurrencesA = RandomReminderScheduler.desiredOccurrences(for: reminderA, from: reference, daysAhead: 1)
        let occurrencesB = RandomReminderScheduler.desiredOccurrences(for: reminderB, from: reference, daysAhead: 1)

        XCTAssertNotEqual(occurrencesA.map(\.date), occurrencesB.map(\.date))
    }

    func testMisconfiguredReminderProducesNoOccurrences() {
        let reminder = Reminder(title: "Broken", scope: .global, triggerType: .random)
        let occurrences = RandomReminderScheduler.desiredOccurrences(for: reminder, from: midnightToday(), daysAhead: 5)
        XCTAssertTrue(occurrences.isEmpty)
    }
}
