import SwiftUI
import UIKit
import CoreLocation
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator
    @Environment(\.modelContext) private var modelContext

    @State private var pendingCount = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    LabeledContent("Status", value: locationStatusLabel)
                    LabeledContent(
                        "Monitored places",
                        value: "\(locationManager.activelyMonitoredPlaceIDs.count) of \(locationManager.totalCandidatePlaceCount)"
                    )
                    if locationManager.totalCandidatePlaceCount > LocationManager.maxMonitoredRegions {
                        Text("iOS limits apps to \(LocationManager.maxMonitoredRegions) monitored places at once. BrainCamp prioritizes your most important, closest places and swaps others in as you move.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if locationManager.authorizationStatus != .authorizedAlways {
                        Button("Open Settings App") { openSystemSettings() }
                    }
                }

                Section("Notifications") {
                    LabeledContent("Status", value: notificationStatusLabel)
                    LabeledContent("Pending", value: "\(pendingCount) of 64")
                    if notificationManager.authorizationStatus != .authorized {
                        Button("Open Settings App") { openSystemSettings() }
                    }
                }

                Section {
                    Button("Re-sync now") {
                        Task { await resync() }
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await refresh() }
        }
    }

    private var locationStatusLabel: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While using app"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        default: return "Not requested"
        }
    }

    private var notificationStatusLabel: String {
        switch notificationManager.authorizationStatus {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .provisional: return "Provisional"
        default: return "Not requested"
        }
    }

    private func refresh() async {
        await notificationManager.refreshAuthorizationStatus()
        pendingCount = await notificationManager.pendingNotificationCount()
    }

    private func resync() async {
        await reminderCoordinator.resyncEverything(context: modelContext)
        await refresh()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
