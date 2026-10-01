import Foundation

/// A cancellable piece of scheduled work.
public protocol Cancellable {
    func cancel()
}

/// Schedules a closure to run once after a delay, and tells the time.
/// The app uses `TimerScheduler`; tests use a manual scheduler they can advance by hand.
public protocol Scheduling {
    func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) -> Cancellable
    func now() -> Date
}

/// Real scheduler backed by `Timer` on the main run loop.
public final class TimerScheduler: Scheduling {
    public init() {}

    public func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) -> Cancellable {
        let timer = Timer.scheduledTimer(withTimeInterval: max(seconds, 0), repeats: false) { _ in work() }
        // Keep firing even while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        return TimerToken(timer: timer)
    }

    public func now() -> Date { Date() }

    private struct TimerToken: Cancellable {
        let timer: Timer
        func cancel() { timer.invalidate() }
    }
}
