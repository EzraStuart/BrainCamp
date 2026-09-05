import XCTest
@testable import BrainCamp

final class RegionPriorityTests: XCTestCase {
    func testHigherImportanceWinsRegardlessOfDistance() {
        let critical = RegionPriority.Candidate(
            id: UUID(), importance: .critical, distanceMeters: 5000, mostRecentReminderDate: .distantPast
        )
        let low = RegionPriority.Candidate(
            id: UUID(), importance: .low, distanceMeters: 10, mostRecentReminderDate: .now
        )

        let ranked = RegionPriority.rank([low, critical])
        XCTAssertEqual(ranked.first, critical.id)
    }

    func testCloserPlaceWinsWhenImportanceTied() {
        let near = RegionPriority.Candidate(
            id: UUID(), importance: .medium, distanceMeters: 50, mostRecentReminderDate: .distantPast
        )
        let far = RegionPriority.Candidate(
            id: UUID(), importance: .medium, distanceMeters: 5000, mostRecentReminderDate: .now
        )

        let ranked = RegionPriority.rank([far, near])
        XCTAssertEqual(ranked.first, near.id)
    }

    func testUnknownDistanceLosesToKnownDistance() {
        let unknown = RegionPriority.Candidate(
            id: UUID(), importance: .medium, distanceMeters: nil, mostRecentReminderDate: .now
        )
        let known = RegionPriority.Candidate(
            id: UUID(), importance: .medium, distanceMeters: 5000, mostRecentReminderDate: .distantPast
        )

        let ranked = RegionPriority.rank([unknown, known])
        XCTAssertEqual(ranked.first, known.id)
    }

    func testMostRecentReminderBreaksTieWhenDistanceUnknown() {
        let older = RegionPriority.Candidate(
            id: UUID(), importance: .high, distanceMeters: nil, mostRecentReminderDate: .distantPast
        )
        let newer = RegionPriority.Candidate(
            id: UUID(), importance: .high, distanceMeters: nil, mostRecentReminderDate: .now
        )

        let ranked = RegionPriority.rank([older, newer])
        XCTAssertEqual(ranked.first, newer.id)
    }

    func testTopTwentyTruncation() {
        let candidates = (0..<25).map { index in
            RegionPriority.Candidate(
                id: UUID(),
                importance: .medium,
                distanceMeters: Double(index),
                mostRecentReminderDate: .now
            )
        }
        let ranked = RegionPriority.rank(candidates)
        let top20 = Array(ranked.prefix(20))
        XCTAssertEqual(top20.count, 20)
        // Closest 20 (indices 0..<20) should be the ones kept, in order.
        XCTAssertEqual(top20, Array(candidates.prefix(20).map(\.id)))
    }
}
