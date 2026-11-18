import Foundation
import Synchronization
import Testing
@testable import Curbside

@MainActor @Suite struct AppLockTests {
    private let defaults = UserDefaults(suiteName: UUID().uuidString)!
    private final class Count: Sendable {
        let value = Mutex(0)
    }

    private let count = Count()
    private var prompts: Int { count.value.withLock { $0 } }

    private func lock(passcode: Bool = true, face: Bool = true) -> AppLock {
        let count = count
        return AppLock(defaults: defaults, device: .init(canLock: { passcode }, authenticate: { _ in
            count.value.withLock { $0 += 1 }
            return face
        }))
    }

    @Test func locksAtLaunchByDefault() async {
        let lock = lock()
        #expect(lock.isEnabled)
        #expect(lock.isLocked)
        await lock.unlock()
        #expect(!lock.isLocked)
        #expect(prompts == 1)
    }

    @Test func failedMatchStaysLocked() async {
        let lock = lock(face: false)
        await lock.unlock()
        #expect(lock.isLocked)
    }

    @Test func locksAgainFromTheBackground() async {
        let lock = lock()
        await lock.unlock()
        lock.lock()
        #expect(lock.isLocked)
    }

    @Test func turnedOffStaysOffNextLaunch() async {
        let first = lock()
        await first.unlock()
        first.isEnabled = false
        first.lock()
        #expect(!first.isLocked)
        #expect(!lock().isLocked)
    }

    @Test func noPasscodeNoLock() async {
        let lock = lock(passcode: false)
        #expect(!lock.isLocked)
        await lock.unlock()
        #expect(prompts == 0)
    }
}
