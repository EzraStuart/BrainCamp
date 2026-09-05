import Foundation
import SwiftData

/// Owns the shared `ModelContainer`. Exposed statically because
/// `NotificationManager`'s `UNUserNotificationCenterDelegate` callbacks fire
/// outside the SwiftUI view hierarchy and can't reach `@Environment(\.modelContext)`.
enum PersistenceController {
    static let shared: ModelContainer = {
        let schema = Schema([
            Item.self,
            Place.self,
            Reminder.self,
            LastSeenEntry.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @MainActor
    static var mainContext: ModelContext {
        shared.mainContext
    }
}
