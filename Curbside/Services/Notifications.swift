import Foundation
import Observation
import UIKit
import UserNotifications

/// Push for street activity, and the opt-in weekly "due for a hello" reminder. Both hang off the one iOS permission,
/// asked for after you first share or join a street rather than on launch.
@MainActor @Observable
final class Notifications {
    nonisolated static let tokenKey = "pushToken"
    nonisolated static let reminderKey = "helloReminder"
    nonisolated static let reminderID = "hello-reminder"

    private(set) var status = UNAuthorizationStatus.notDetermined
    private(set) var reminderOn: Bool

    private let api: APIClient
    private let defaults: UserDefaults
    private let environment: String

    init(api: APIClient, defaults: UserDefaults, environment: String = Config.apnsEnvironment) {
        self.api = api
        self.defaults = defaults
        self.environment = environment
        reminderOn = defaults.bool(forKey: Self.reminderKey)
    }

    private var center: UNUserNotificationCenter { .current() }

    /// Reads the permission, and re-registers when it's granted: the token can change across restores and reinstalls.
    func refresh() async {
        status = await center.notificationSettings().authorizationStatus
        if status == .authorized { UIApplication.shared.registerForRemoteNotifications() }
    }

    /// Asks once. After that only iOS Settings changes the answer.
    func ask() async {
        await refresh()
        guard status == .notDetermined else { return }
        // A thrown error is the same as a no: nothing gets registered.
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refresh()
    }

    /// APNs handed over this phone's token; the next launch retries a failed PUT.
    func registered(_ token: Data) async {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        guard (try? await api.send("/v1/devices/\(hex)", method: "PUT", body: Device(env: environment))) != nil else { return }
        defaults.set(hex, forKey: Self.tokenKey)
    }

    /// Sign-out: stop this account's pushes to the phone and drop its reminder. `api` signs as the outgoing account.
    func forget(using api: APIClient) async {
        reminderOn = false
        defaults.removeObject(forKey: Self.reminderKey)
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
        guard let token = defaults.string(forKey: Self.tokenKey) else { return }
        defaults.removeObject(forKey: Self.tokenKey)
        // Best effort: a token left behind is re-homed by the next account's PUT, or pruned when APNs rejects it.
        try? await api.send("/v1/devices/\(token)", method: "DELETE")
    }

    func setReminder(_ on: Bool, due: Int, street: String) async {
        if on {
            await ask()
            guard status == .authorized else { return }
        }
        reminderOn = on
        defaults.set(on, forKey: Self.reminderKey)
        await updateReminder(due: due, street: street)
    }

    /// Re-dates the reminder's count. Nobody due means no reminder at all, not one that says zero.
    func updateReminder(due: Int, street: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
        guard reminderOn, let request = Self.reminder(due: due, street: street) else { return }
        // Scheduling only fails without permission, which the settings row already shows.
        try? await center.add(request)
    }

    /// Saturdays at 10.
    nonisolated static func reminder(due: Int, street: String) -> UNNotificationRequest? {
        guard due > 0 else { return nil }
        let content = UNMutableNotificationContent()
        content.title = "Due for a hello"
        content.body = due == 1 ? "1 neighbor on \(street) is due for a hello." : "\(due) neighbors on \(street) are due for a hello."
        var when = DateComponents()
        when.weekday = 7
        when.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        return UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
    }

    /// Households you haven't talked to in 30 days, or ever. The web profile's "due for a hello" uses the same month.
    nonisolated static func due(_ households: [Household], now: Date = .now) -> Int {
        let cutoff = now.addingTimeInterval(-30 * 86_400)
        return households.count { ($0.mine.lastTalkedAt?.isoDate ?? .distantPast) < cutoff }
    }
}

private struct Device: Encodable, Sendable {
    let platform = "ios"
    let env: String
}
