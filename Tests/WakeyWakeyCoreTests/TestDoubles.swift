import Foundation
import XCTest
@testable import WakeyWakeyCore

/// Records assertion calls without touching IOKit.
final class SpySleepPreventer: SleepPreventing {
    private(set) var isPreventingSleep = false
    private(set) var preventCalls: [String] = []
    private(set) var allowCalls = 0
    var refuse = false

    @discardableResult
    func preventSleep(reason: String) -> Bool {
        preventCalls.append(reason)
        if refuse { return false }
        isPreventingSleep = true
        return true
    }

    func allowSleep() {
        allowCalls += 1
        isPreventingSleep = false
    }
}

/// A scheduler tests can advance by hand, with a controllable clock.
final class ManualScheduler: Scheduling {
    final class Job: Cancellable {
        let delay: TimeInterval
        let fireAt: Date
        let work: () -> Void
        private(set) var isCancelled = false
        private(set) var fired = false
        init(delay: TimeInterval, fireAt: Date, work: @escaping () -> Void) {
            self.delay = delay; self.fireAt = fireAt; self.work = work
        }
        func cancel() { isCancelled = true }
        func fire() {
            guard !isCancelled, !fired else { return }
            fired = true
            work()
        }
    }

    var currentTime: Date
    private(set) var jobs: [Job] = []

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        currentTime = now
    }

    var pendingJobs: [Job] { jobs.filter { !$0.isCancelled && !$0.fired } }

    func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) -> Cancellable {
        let job = Job(delay: seconds, fireAt: currentTime.addingTimeInterval(seconds), work: work)
        jobs.append(job)
        return job
    }

    func now() -> Date { currentTime }

    /// Move the clock forward, firing any jobs that fall due (in order).
    func advance(by seconds: TimeInterval) {
        let target = currentTime.addingTimeInterval(seconds)
        for job in pendingJobs.sorted(by: { $0.fireAt < $1.fireAt }) where job.fireAt <= target {
            currentTime = job.fireAt
            job.fire()
        }
        currentTime = target
    }

    func fireAll() {
        for job in pendingJobs { job.fire() }
    }
}

/// Fresh, isolated defaults per test.
func makeTestDefaults(_ name: String = #function) -> UserDefaults {
    let suite = "WakeyWakeyTests.\(name).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
