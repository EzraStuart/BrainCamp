import SwiftUI
import SwiftData

private enum GroupMode: String, CaseIterable, Identifiable {
    case importance = "Importance"
    case place = "Place"
    var id: String { rawValue }
}

struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator

    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @State private var groupMode: GroupMode = .importance
    @State private var newItem: Item?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No items yet",
                        systemImage: "shippingbox",
                        description: Text("Add the things you don't want to forget or lose.")
                    )
                } else {
                    List {
                        ForEach(groupedSections, id: \.title) { section in
                            Section(section.title) {
                                ForEach(section.items) { item in
                                    NavigationLink {
                                        ItemDetailView(item: item)
                                    } label: {
                                        ItemRow(item: item)
                                    }
                                }
                                .onDelete { offsets in delete(section.items, at: offsets) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Group by", selection: $groupMode) {
                        ForEach(GroupMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addItem()
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $newItem) { item in
                NavigationStack {
                    ItemEditView(item: item, isNew: true)
                }
            }
        }
    }

    private var groupedSections: [(title: String, items: [Item])] {
        switch groupMode {
        case .importance:
            return Importance.allCases.reversed().compactMap { level in
                let matching = items.filter { $0.importance == level }
                return matching.isEmpty ? nil : (level.label, matching)
            }
        case .place:
            var byPlace: [String: [Item]] = [:]
            for item in items {
                byPlace[item.designatedPlace?.name ?? "No place set", default: []].append(item)
            }
            return byPlace.keys.sorted().map { ($0, byPlace[$0] ?? []) }
        }
    }

    private func addItem() {
        let item = Item(name: "")
        modelContext.insert(item)
        newItem = item
    }

    private func delete(_ items: [Item], at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            for reminder in item.localReminders {
                reminderCoordinator.reminderWillDelete(reminder)
            }
            modelContext.delete(item)
        }
    }
}

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack {
            Image(systemName: item.iconSystemName ?? "shippingbox.fill")
                .foregroundStyle(item.importance.color)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(item.name)
                if let place = item.designatedPlace {
                    Text(place.name).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !item.localReminders.filter(\.isEnabled).isEmpty {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
