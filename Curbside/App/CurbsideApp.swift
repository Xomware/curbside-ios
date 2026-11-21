import SwiftUI

@main
struct CurbsideApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            RootView(model: delegate.root)
        }
    }
}

/// Owns the root model so APNs callbacks and notification taps, which arrive here, can reach it.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let root: RootModel = {
        #if DEBUG
        if Demo.scenario != nil { return Demo.rootModel() }
        #endif
        return RootModel.live()
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await root.notifications.registered(deviceToken) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// A push opens the activity feed; the hello reminder just opens the map.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.identifier != Notifications.reminderID else { return }
        await MainActor.run { root.pendingActivity = true }
    }
}
