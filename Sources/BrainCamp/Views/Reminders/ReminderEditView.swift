import SwiftUI
import SwiftData

/// Shared add/edit form for a `Reminder`, local or global. Callers insert a
/// fresh `Reminder` into the context and present this view with `isNew: true`
/// (mirroring `ItemEditView`'s pattern); on cancel the transient object is
/// deleted again.
struct ReminderEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator
    @EnvironmentObject private var locationManager: LocationManager

    @Query(sort: \Place.name) private var places: [Place]

    @Bindable var reminder: Reminder
    let isNew: Bool

    @State private var recurringTime: Date
    @State private var selectedWeekdays: Set<Int>
    @State private var oneTimeDate: Date
    @State private var randomWindowStart: Date
    @State private var randomWindowEnd: Date
    @State private var randomFrequency: Int

    init(reminder: Reminder, isNew: Bool) {
        _reminder = Bindable(reminder)
        self.isNew = isNew

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)

        _recurringTime = State(initialValue: calendar.date(
            bySettingHour: reminder.recurringHour ?? 9, minute: reminder.recurringMinute ?? 0, second: 0, of: .now
        ) ?? .now)
        _selectedWeekdays = State(initialValue: Set(reminder.recurringWeekdays ?? []))
        _oneTimeDate = State(initialValue: reminder.oneTimeDate ?? .now.addingTimeInterval(3600))
        _randomWindowStart = State(initialValue: calendar.date(
            byAdding: .minute, value: reminder.randomWindowStartMinutes ?? 9 * 60, to: startOfDay
        ) ?? .now)
        _randomWindowEnd = State(initialValue: calendar.date(
            byAdding: .minute, value: reminder.randomWindowEndMinutes ?? 21 * 60, to: startOfDay
        ) ?? .now)
        _randomFrequency = State(initialValue: reminder.randomFrequencyPerDay ?? 2)
    }

    var body: some View {
        Form {
            Section("Reminder") {
                TextField("Title", text: $reminder.title)
                if reminder.item == nil {
                    Text("Global reminder — not tied to a specific item.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let item = reminder.item {
                    LabeledContent("Item", value: item.name)
                }
            }

            Section("Trigger") {
                Picker("Type", selection: $reminder.triggerType) {
                    ForEach(TriggerType.allCases) { type in
                        Label(type.label, systemImage: type.systemImage).tag(type)
                    }
                }

                switch reminder.triggerType {
                case .recurring:
                    DatePicker("Time", selection: $recurringTime, displayedComponents: .hourAndMinute)
                    WeekdayPicker(selection: $selectedWeekdays)
                case .oneTime:
                    DatePicker("When", selection: $oneTimeDate)
                case .location:
                    Picker("Place", selection: $reminder.place) {
                        Text("None").tag(Place?.none)
                        ForEach(places) { place in
                            Text(place.name).tag(Optional(place))
                        }
                    }
                    Picker("Event", selection: Binding(
                        get: { reminder.geofenceEvent ?? .both },
                        set: { reminder.geofenceEvent = $0 }
                    )) {
                        ForEach(GeofenceEvent.allCases) { event in
                            Text(event.label).tag(event)
                        }
                    }
                case .random:
                    Stepper("Check-ins per day: \(randomFrequency)", value: $randomFrequency, in: 1...10)
                    DatePicker("Window start", selection: $randomWindowStart, displayedComponents: .hourAndMinute)
                    DatePicker("Window end", selection: $randomWindowEnd, displayedComponents: .hourAndMinute)
                }
            }

            Section("Notification style") {
                Picker("Style", selection: $reminder.notificationStyle) {
                    ForEach(NotificationStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                if reminder.notificationStyle == .checkIn {
                    Text("Check-in notifications ask \u{201C}Do you have it?\u{201D} with Yes/No buttons, and log the response to this item's history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("One-time use", isOn: $reminder.isTransient)
                Text("Turns itself off after firing once — handy for something you only need a reminder about occasionally, like earrings for a night out.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Enabled", isOn: $reminder.isEnabled)
            }
        }
        .navigationTitle(isNew ? "New Reminder" : "Edit Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if isNew { modelContext.delete(reminder) }
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .disabled(reminder.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onChange(of: reminder.triggerType) { _, newValue in
            // Ask for the "Always" location upgrade at the moment it's
            // actually needed, rather than chaining it onto onboarding.
            if newValue == .location {
                locationManager.requestWhenInUseThenAlways()
            }
        }
    }

    private func save() {
        let calendar = Calendar.current
        switch reminder.triggerType {
        case .recurring:
            let comps = calendar.dateComponents([.hour, .minute], from: recurringTime)
            reminder.recurringHour = comps.hour
            reminder.recurringMinute = comps.minute
            reminder.recurringWeekdays = Array(selectedWeekdays)
            reminder.oneTimeDate = nil
            reminder.place = nil
            reminder.geofenceEvent = nil
            reminder.randomFrequencyPerDay = nil
        case .oneTime:
            reminder.oneTimeDate = oneTimeDate
            reminder.recurringHour = nil
            reminder.recurringMinute = nil
            reminder.recurringWeekdays = nil
            reminder.place = nil
            reminder.geofenceEvent = nil
            reminder.randomFrequencyPerDay = nil
        case .location:
            if reminder.geofenceEvent == nil { reminder.geofenceEvent = .both }
            reminder.oneTimeDate = nil
            reminder.recurringHour = nil
            reminder.recurringMinute = nil
            reminder.recurringWeekdays = nil
            reminder.randomFrequencyPerDay = nil
        case .random:
            let startOfDay = calendar.startOfDay(for: .now)
            reminder.randomFrequencyPerDay = randomFrequency
            reminder.randomWindowStartMinutes = calendar.dateComponents([.minute], from: startOfDay, to: randomWindowStart).minute
            reminder.randomWindowEndMinutes = calendar.dateComponents([.minute], from: startOfDay, to: randomWindowEnd).minute
            reminder.oneTimeDate = nil
            reminder.recurringHour = nil
            reminder.recurringMinute = nil
            reminder.recurringWeekdays = nil
            reminder.place = nil
            reminder.geofenceEvent = nil
        }

        try? modelContext.save()
        reminderCoordinator.reminderDidChange(reminder)
    }
}

private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack {
            ForEach(Weekday.allCases) { day in
                let isSelected = selection.contains(day.rawValue)
                Button {
                    if isSelected { selection.remove(day.rawValue) } else { selection.insert(day.rawValue) }
                } label: {
                    Text(day.shortLabel.prefix(1))
                        .frame(width: 28, height: 28)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            if selection.isEmpty {
                Text("No days selected = every day")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .offset(y: 20)
            }
        }
    }
}
