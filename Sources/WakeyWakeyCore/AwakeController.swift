import Foundation

/// The heart of the app: an on/off switch for sleep prevention with an optional timeout.
public final class AwakeController {
    public enum State: Equatable {
        case asleep                 // normal: Mac may sleep
        case awake(until: Date?)    // nil = indefinitely
    }

    public static let assertionReason = "Wakey Wakey is keeping your Mac awake"

    private let preventer: SleepPreventing
    private let scheduler: Scheduling
    private var timeout: Cancellable?
    private var deadline: Date?

    /// Called whenever the state changes.
    public var onStateChange: ((State) -> Void)?

    public init(preventer: SleepPreventing, scheduler: Scheduling) {
        self.preventer = preventer
        self.scheduler = scheduler
    }

    public var isAwake: Bool { preventer.isPreventingSleep }

    public var state: State {
        isAwake ? .awake(until: deadline) : .asleep
    }

    /// Seconds left before auto-off, or nil if indefinite / not awake.
    public var remaining: TimeInterval? {
        guard isAwake, let deadline else { return nil }
        return max(0, deadline.timeIntervalSince(scheduler.now()))
    }

    /// Keep the Mac awake for `duration`. Calling again while awake replaces the timeout.
    public func activate(for duration: Duration) {
        let before = state
        if !preventer.isPreventingSleep {
            guard preventer.preventSleep(reason: Self.assertionReason) else { return }
        }
        cancelTimeout()
        if let seconds = duration.seconds {
            deadline = scheduler.now().addingTimeInterval(seconds)
            timeout = scheduler.schedule(after: seconds) { [weak self] in self?.timeoutFired() }
        } else {
            deadline = nil
        }
        notifyIfChanged(from: before)
    }

    public func deactivate() {
        let before = state
        cancelTimeout()
        deadline = nil
        preventer.allowSleep()
        notifyIfChanged(from: before)
    }

    /// Left-click behaviour: off if on, otherwise on for `duration`.
    public func toggle(duration: Duration) {
        isAwake ? deactivate() : activate(for: duration)
    }

    /// Release everything; call on quit.
    public func shutdown() { deactivate() }

    // MARK: - Private

    private func timeoutFired() {
        timeout = nil
        deactivate()
    }

    private func cancelTimeout() {
        timeout?.cancel()
        timeout = nil
    }

    private func notifyIfChanged(from before: State) {
        let now = state
        if now != before { onStateChange?(now) }
    }
}
