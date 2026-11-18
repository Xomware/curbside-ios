import Foundation
import LocalAuthentication
import Observation

/// Face ID, falling back to the passcode, in front of everything you've written about your neighbours. On unless
/// turned off; a phone without a passcode can't lock.
@MainActor @Observable
final class AppLock {
    struct Device: Sendable {
        var canLock: @Sendable () -> Bool
        var authenticate: @Sendable (String) async -> Bool

        static let live = Device(
            canLock: { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) },
            // A cancel or a failed match is just "still locked"; the lock screen offers another try.
            authenticate: { reason in (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false }
        )
    }

    nonisolated static let key = "appLock"

    private(set) var isLocked: Bool
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.key) }
    }

    private let defaults: UserDefaults
    private let device: Device
    @ObservationIgnored private var unlocking = false

    init(defaults: UserDefaults = .standard, device: Device = .live) {
        self.defaults = defaults
        self.device = device
        isEnabled = defaults.object(forKey: Self.key) as? Bool ?? true
        isLocked = false
        lock()
    }

    var canLock: Bool { device.canLock() }

    /// At launch and whenever the app goes to the background.
    func lock() {
        if isEnabled && device.canLock() { isLocked = true }
    }

    func unlock() async {
        guard isLocked, !unlocking else { return }
        unlocking = true
        defer { unlocking = false }
        if await device.authenticate("Unlock your street") { isLocked = false }
    }
}
