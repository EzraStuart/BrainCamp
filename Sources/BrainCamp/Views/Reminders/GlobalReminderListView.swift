import SwiftUI
import SwiftData

// SwiftData's #Predicate macro mis-expands a bare `EnumType.case` written
// directly inside the predicate closure into an invalid key path. Capturing
// the case in a plain variable outside the closure works around it.
private let globalScope = ReminderScope.global

struct GlobalReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator

    @Query(
        filter: #Predicate<Reminder> { $0.scope == globalScope },
        sort: \Reminder.createdAt,
        order: .reverse
    )
    private var globalReminders: [Reminder]

    @State private var newReminder: Reminder?

    var body: some View {
        NavigationStack {
            Group {
                if globalReminders.isEmpty {
                    ContentUnavailableView(
                        "No global reminders",
                        systemImage: "bell.badge",
                        description: Text("Global reminders aren't tied to one item — use them for general nudges.")
                    )
                } else {
                    List {
                        ForEach(TriggerType.allCases) { type in
                            let matching = globalReminders.filter { $0.triggerType == type }
                            if !matching.isEmpty {
                                Section(type.label) {
                                    ForEach(matching) { reminder in
                                        NavigationLink {
                                            ReminderEditView(reminder: reminder, isNew: false)
                                        } label: {
                                            ReminderRow(reminder: reminder)
                                        }
                                    }
                                    .onDelete { offsets in delete(matching, at: offsets) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addReminder()
                    } label: {
                        Label("Add reminder", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $newReminder) { reminder in
                NavigationStack {
                    ReminderEditView(reminder: reminder, isNew: true)
                }
            }
        }
    }

    private func addReminder() {
        let reminder = Reminder(title: "", scope: .global, triggerType: .recurring)
        modelContext.insert(reminder)
        newReminder = reminder
    }

    private func delete(_ reminders: [Reminder], at offsets: IndexSet) {
        for index in offsets {
            let reminder = reminders[index]
            reminderCoordinator.reminderWillDelete(reminder)
            modelContext.delete(reminder)
        }
    }
}
