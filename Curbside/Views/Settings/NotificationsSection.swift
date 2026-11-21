import SwiftUI

/// Whether street activity can reach this phone, and the weekly "due for a hello" reminder for the open street.
struct NotificationsSection: View {
    let notifications: Notifications
    /// The open street's name and how many of its households are due; nil before there is one.
    let street: (name: String, due: Int)?

    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            switch notifications.status {
            case .notDetermined:
                Button("Turn on notifications") { Task { await notifications.ask() } }
            case .denied:
                Button("Turned off in iOS Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
            default:
                LabeledContent("Street activity", value: "On")
            }
            if let street {
                Toggle("Weekly hello reminder", isOn: Binding(
                    get: { notifications.reminderOn },
                    set: { on in Task { await notifications.setReminder(on, due: street.due, street: street.name) } }
                ))
                .tint(Palette.signGreen)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(footer)
        }
        .task { await notifications.refresh() }
    }

    private var footer: String {
        let activity = "Hear when someone joins or adds to a street you share, or becomes your friend."
        guard let street else { return activity }
        let due = street.due == 1 ? "1 neighbor is" : "\(street.due) neighbors are"
        return "\(activity) The reminder comes Saturday mornings; \(due) due for a hello on \(street.name) now."
    }
}
