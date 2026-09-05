import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator
    @EnvironmentObject private var locationManager: LocationManager

    @Bindable var item: Item

    @State private var showingEdit = false
    @State private var newReminder: Reminder?
    @State private var isLocatingCurrentPosition = false

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: item.iconSystemName ?? "shippingbox.fill")
                        .font(.title2)
                        .foregroundStyle(item.importance.color)
                    VStack(alignment: .leading) {
                        Text(item.name).font(.headline)
                        Text(item.importance.label).font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let place = item.designatedPlace {
                    Map(initialPosition: .region(
                        MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 600, longitudinalMeters: 600)
                    )) {
                        Marker(place.name, coordinate: place.coordinate)
                        MapCircle(center: place.coordinate, radius: place.radiusMeters)
                            .foregroundStyle(.blue.opacity(0.15))
                            .stroke(.blue, lineWidth: 2)
                    }
                    .frame(height: 160)
                    .allowsHitTesting(false)
                    Text("Designated place: \(place.name)")
                        .font(.subheadline)
                } else {
                    Text("No designated place set")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Reminders") {
                if item.localReminders.isEmpty {
                    Text("No reminders yet").foregroundStyle(.secondary)
                }
                ForEach(item.localReminders) { reminder in
                    NavigationLink {
                        ReminderEditView(reminder: reminder, isNew: false)
                    } label: {
                        ReminderRow(reminder: reminder)
                    }
                }
                .onDelete(perform: deleteReminders)

                Button {
                    addReminder()
                } label: {
                    Label("Add reminder", systemImage: "plus")
                }
            }

            Section("Log where it is") {
                Button {
                    logAtDesignatedPlace()
                } label: {
                    Label("Mark at designated place", systemImage: "checkmark.circle")
                }
                .disabled(item.designatedPlace == nil)

                Button {
                    logAtCurrentLocation()
                } label: {
                    Label(
                        isLocatingCurrentPosition ? "Finding your location…" : "Log at current location",
                        systemImage: "location.circle"
                    )
                }
                .disabled(isLocatingCurrentPosition)
            }

            Section("History") {
                let entries = item.lastSeenEntries.sorted(by: { $0.timestamp > $1.timestamp })
                if entries.isEmpty {
                    Text("No history yet").foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.locationDescription)
                        Text("\(entry.source.label) · \(entry.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack { ItemEditView(item: item, isNew: false) }
        }
        .sheet(item: $newReminder) { reminder in
            NavigationStack {
                ReminderEditView(reminder: reminder, isNew: true)
            }
        }
    }

    private func addReminder() {
        let reminder = Reminder(title: "", scope: .local, triggerType: .recurring, item: item)
        modelContext.insert(reminder)
        newReminder = reminder
    }

    private func logAtDesignatedPlace() {
        guard let place = item.designatedPlace else { return }
        modelContext.insert(LastSeenEntry(item: item, place: place, source: .manual))
        try? modelContext.save()
    }

    private func logAtCurrentLocation() {
        isLocatingCurrentPosition = true
        locationManager.requestOneTimeLocation { location in
            isLocatingCurrentPosition = false
            guard let location else { return }
            let entry = LastSeenEntry(
                item: item,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                source: .manual,
                note: "Logged at current location"
            )
            modelContext.insert(entry)
            try? modelContext.save()
        }
    }

    private func deleteReminders(at offsets: IndexSet) {
        for index in offsets {
            let reminder = item.localReminders[index]
            reminderCoordinator.reminderWillDelete(reminder)
            modelContext.delete(reminder)
        }
    }
}
