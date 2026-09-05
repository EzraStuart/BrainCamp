import SwiftUI
import SwiftData

@main
struct BrainCampApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var locationManager: LocationManager
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var reminderCoordinator: ReminderCoordinator

    init() {
        let location = LocationManager()
        _locationManager = StateObject(wrappedValue: location)
        _reminderCoordinator = StateObject(wrappedValue: ReminderCoordinator(locationManager: location))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(locationManager)
            .environmentObject(notificationManager)
            .environmentObject(reminderCoordinator)
        }
        .modelContainer(PersistenceController.shared)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { @MainActor in
                    await reminderCoordinator.resyncEverything(context: PersistenceController.mainContext)
                }
            }
        }
    }
}
