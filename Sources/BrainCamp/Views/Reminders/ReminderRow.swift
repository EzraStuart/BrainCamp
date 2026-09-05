import SwiftUI

struct ReminderRow: View {
    @EnvironmentObject private var reminderCoordinator: ReminderCoordinator
    @Bindable var reminder: Reminder

    var body: some View {
        HStack {
            Image(systemName: reminder.triggerType.systemImage)
                .foregroundStyle(reminder.isEnabled ? .primary : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title.isEmpty ? reminder.triggerType.label : reminder.title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $reminder.isEnabled)
                .labelsHidden()
                .onChange(of: reminder.isEnabled) { _, _ in
                    reminderCoordinator.reminderDidChange(reminder)
                }
        }
    }

    private var subtitle: String {
        var parts = [reminder.triggerType.label]
        if reminder.isTransient { parts.append("one-time use") }
        if reminder.isMisconfigured { parts.append("needs setup") }
        return parts.joined(separator: " · ")
    }
}
