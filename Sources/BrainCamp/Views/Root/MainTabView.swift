import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ItemListView()
                .tabItem { Label("Items", systemImage: "shippingbox.fill") }
            GlobalReminderListView()
                .tabItem { Label("Reminders", systemImage: "bell.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
