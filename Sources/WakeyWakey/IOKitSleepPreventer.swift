import Foundation
import IOKit.pwr_mgt
import WakeyWakeyCore

/// Real sleep prevention via IOKit power-management assertions.
final class IOKitSleepPreventer: SleepPreventing {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isPreventingSleep = false

    /// If true, the display stays on too (kIOPMAssertionTypeNoDisplaySleep); otherwise only
    /// idle system sleep is blocked (kIOPMAssertionTypeNoIdleSleep) and the screen may dim.
    var preventDisplaySleep: Bool

    init(preventDisplaySleep: Bool) {
        self.preventDisplaySleep = preventDisplaySleep
    }

    @discardableResult
    func preventSleep(reason: String) -> Bool {
        guard !isPreventingSleep else { return true }
        let type = preventDisplaySleep
            ? kIOPMAssertionTypeNoDisplaySleep as CFString
            : kIOPMAssertionTypeNoIdleSleep as CFString
        let result = IOPMAssertionCreateWithName(
            type, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &assertionID)
        isPreventingSleep = result == kIOReturnSuccess
        return isPreventingSleep
    }

    func allowSleep() {
        guard isPreventingSleep else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isPreventingSleep = false
    }

    deinit { allowSleep() }
}
