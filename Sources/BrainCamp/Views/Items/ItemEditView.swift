import SwiftUI
import SwiftData

private let iconChoices = [
    "key.fill", "wallet.pass.fill", "bag.fill", "case.fill", "eyeglasses",
    "umbrella.fill", "airpodspro", "laptopcomputer", "cross.case.fill", "creditcard.fill",
]

/// Shared add/edit form for an `Item`. For "add," the caller inserts a
/// transient `Item` into the context before presenting this view and deletes
/// it again if the user cancels; for "edit," `@Bindable` edits live in place
/// per SwiftData's standard pattern.
struct ItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator

    @Query(sort: \Place.name) private var places: [Place]

    @Bindable var item: Item
    let isNew: Bool

    @State private var showingPlacePicker = false
    @State private var showingPlaceChooser = false

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $item.name)
                Picker("Importance", selection: $item.importance) {
                    ForEach(Importance.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                TextField(
                    "Notes",
                    text: Binding(get: { item.notes ?? "" }, set: { item.notes = $0.isEmpty ? nil : $0 }),
                    axis: .vertical
                )
            }

            Section("Designated place") {
                if let place = item.designatedPlace {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(place.name)
                            Text("\(Int(place.radiusMeters))m radius")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Change") { showingPlaceChooser = true }
                    }
                } else {
                    Button("Set designated place") { showingPlaceChooser = true }
                }
            }

            Section("Icon") {
                Picker("Icon", selection: Binding(
                    get: { item.iconSystemName ?? iconChoices[0] },
                    set: { item.iconSystemName = $0 }
                )) {
                    ForEach(iconChoices, id: \.self) { icon in
                        Label(icon, systemImage: icon).tag(icon)
                    }
                }
                .pickerStyle(.navigationLink)
            }
        }
        .navigationTitle(isNew ? "New Item" : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        modelContext.delete(item)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { dismiss() }
                        .disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .confirmationDialog("Designated place", isPresented: $showingPlaceChooser, titleVisibility: .visible) {
            ForEach(places) { place in
                Button(place.name) {
                    item.designatedPlace = place
                    reminderCoordinator.itemDidChange(item)
                }
            }
            Button("New place…") { showingPlacePicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingPlacePicker) {
            PlacePickerMapView { name, coordinate, radius in
                let place = Place(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude, radiusMeters: radius)
                modelContext.insert(place)
                item.designatedPlace = place
                reminderCoordinator.itemDidChange(item)
            }
        }
        .onChange(of: item.importance) { _, _ in reminderCoordinator.itemDidChange(item) }
    }
}
