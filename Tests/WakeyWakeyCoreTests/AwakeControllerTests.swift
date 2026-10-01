import XCTest
@testable import WakeyWakeyCore

final class AwakeControllerTests: XCTestCase {
    private var preventer: SpySleepPreventer!
    private var scheduler: ManualScheduler!
    private var controller: AwakeController!
    private var changes: [AwakeController.State] = []

    override func setUp() {
        super.setUp()
        preventer = SpySleepPreventer()
        scheduler = ManualScheduler()
        controller = AwakeController(preventer: preventer, scheduler: scheduler)
        changes = []
        controller.onStateChange = { [weak self] in self?.changes.append($0) }
    }

    // MARK: Initial

    func testStartsAsleep() {
        XCTAssertEqual(controller.state, .asleep)
        XCTAssertFalse(controller.isAwake)
        XCTAssertNil(controller.remaining)
    }

    // MARK: Activate indefinitely

    func testActivateIndefinitelyTakesAssertion() {
        controller.activate(for: .indefinite)
        XCTAssertTrue(preventer.isPreventingSleep)
        XCTAssertEqual(preventer.preventCalls, [AwakeController.assertionReason])
    }

    func testActivateIndefinitelySetsState() {
        controller.activate(for: .indefinite)
        XCTAssertEqual(controller.state, .awake(until: nil))
        XCTAssertTrue(controller.isAwake)
        XCTAssertNil(controller.remaining)
    }

    func testActivateIndefinitelySchedulesNothing() {
        controller.activate(for: .indefinite)
        XCTAssertTrue(scheduler.jobs.isEmpty)
    }

    func testActivateEmitsStateChange() {
        controller.activate(for: .indefinite)
        XCTAssertEqual(changes, [.awake(until: nil)])
    }

    func testIndefiniteStaysAwakeForALongTime() {
        controller.activate(for: .indefinite)
        scheduler.advance(by: 60 * 60 * 24 * 7)
        XCTAssertTrue(controller.isAwake)
    }

    // MARK: Activate with timeout

    func testActivateForMinutesSetsDeadline() {
        controller.activate(for: .minutes(30))
        let expected = scheduler.now().addingTimeInterval(1800)
        XCTAssertEqual(controller.state, .awake(until: expected))
        XCTAssertEqual(controller.remaining, 1800)
    }

    func testActivateForMinutesSchedulesTimeout() {
        controller.activate(for: .minutes(5))
        XCTAssertEqual(scheduler.pendingJobs.count, 1)
        XCTAssertEqual(scheduler.pendingJobs.first?.delay, 300)
    }

    func testRemainingCountsDown() {
        controller.activate(for: .minutes(10))
        scheduler.advance(by: 240)
        XCTAssertEqual(controller.remaining, 360)
    }

    func testTimeoutDeactivates() {
        controller.activate(for: .minutes(5))
        scheduler.advance(by: 300)
        XCTAssertFalse(controller.isAwake)
        XCTAssertFalse(preventer.isPreventingSleep)
        XCTAssertEqual(preventer.allowCalls, 1)
    }

    func testTimeoutEmitsAsleep() {
        controller.activate(for: .minutes(5))
        scheduler.advance(by: 300)
        XCTAssertEqual(changes.last, .asleep)
        XCTAssertEqual(changes.count, 2)
    }

    func testNotDeactivatedBeforeTimeout() {
        controller.activate(for: .minutes(5))
        scheduler.advance(by: 299)
        XCTAssertTrue(controller.isAwake)
    }

    func testRemainingNeverNegative() {
        controller.activate(for: .minutes(1))
        scheduler.currentTime = scheduler.currentTime.addingTimeInterval(5000)   // skip without firing
        XCTAssertEqual(controller.remaining, 0)
    }

    // MARK: Re-activating

    func testReactivateWhileAwakeDoesNotTakeSecondAssertion() {
        controller.activate(for: .minutes(5))
        controller.activate(for: .minutes(10))
        XCTAssertEqual(preventer.preventCalls.count, 1)
    }

    func testReactivateReplacesTimeout() {
        controller.activate(for: .minutes(5))
        let first = scheduler.pendingJobs.first
        controller.activate(for: .minutes(60))
        XCTAssertTrue(first?.isCancelled ?? false)
        XCTAssertEqual(scheduler.pendingJobs.count, 1)
        XCTAssertEqual(controller.remaining, 3600)
    }

    func testReactivateWithIndefiniteClearsTimeout() {
        controller.activate(for: .minutes(5))
        controller.activate(for: .indefinite)
        XCTAssertTrue(scheduler.pendingJobs.isEmpty)
        XCTAssertEqual(controller.state, .awake(until: nil))
        scheduler.advance(by: 10_000)
        XCTAssertTrue(controller.isAwake)
    }

    func testReactivateWithSameDurationEmitsNewDeadline() {
        controller.activate(for: .minutes(5))
        scheduler.advance(by: 60)
        controller.activate(for: .minutes(5))
        XCTAssertEqual(changes.count, 2)
        XCTAssertEqual(controller.remaining, 300)
    }

    func testReactivateIndefiniteWhenAlreadyIndefiniteDoesNotEmit() {
        controller.activate(for: .indefinite)
        controller.activate(for: .indefinite)
        XCTAssertEqual(changes.count, 1)
    }

    // MARK: Deactivate

    func testDeactivateReleasesAssertion() {
        controller.activate(for: .indefinite)
        controller.deactivate()
        XCTAssertFalse(preventer.isPreventingSleep)
        XCTAssertEqual(preventer.allowCalls, 1)
        XCTAssertEqual(controller.state, .asleep)
    }

    func testDeactivateCancelsTimeout() {
        controller.activate(for: .minutes(5))
        controller.deactivate()
        XCTAssertTrue(scheduler.pendingJobs.isEmpty)
        scheduler.advance(by: 600)
        XCTAssertEqual(preventer.allowCalls, 1, "cancelled timeout must not deactivate again")
    }

    func testDeactivateEmitsAsleep() {
        controller.activate(for: .indefinite)
        controller.deactivate()
        XCTAssertEqual(changes, [.awake(until: nil), .asleep])
    }

    func testDeactivateWhenAsleepDoesNotEmit() {
        controller.deactivate()
        XCTAssertTrue(changes.isEmpty)
    }

    func testDeactivateClearsRemaining() {
        controller.activate(for: .minutes(5))
        controller.deactivate()
        XCTAssertNil(controller.remaining)
    }

    // MARK: Toggle

    func testToggleFromAsleepActivates() {
        controller.toggle(duration: .minutes(15))
        XCTAssertTrue(controller.isAwake)
        XCTAssertEqual(controller.remaining, 900)
    }

    func testToggleFromAwakeDeactivates() {
        controller.activate(for: .indefinite)
        controller.toggle(duration: .minutes(15))
        XCTAssertFalse(controller.isAwake)
    }

    func testToggleTwiceReturnsToStart() {
        controller.toggle(duration: .indefinite)
        controller.toggle(duration: .indefinite)
        XCTAssertEqual(controller.state, .asleep)
        XCTAssertEqual(changes, [.awake(until: nil), .asleep])
    }

    // MARK: Refusal

    func testRefusedAssertionLeavesAsleep() {
        preventer.refuse = true
        controller.activate(for: .minutes(5))
        XCTAssertEqual(controller.state, .asleep)
        XCTAssertTrue(scheduler.jobs.isEmpty)
        XCTAssertTrue(changes.isEmpty)
    }

    func testCanRetryAfterRefusal() {
        preventer.refuse = true
        controller.activate(for: .indefinite)
        preventer.refuse = false
        controller.activate(for: .indefinite)
        XCTAssertTrue(controller.isAwake)
    }

    // MARK: Shutdown

    func testShutdownReleasesAssertionAndTimeout() {
        controller.activate(for: .minutes(5))
        controller.shutdown()
        XCTAssertFalse(preventer.isPreventingSleep)
        XCTAssertTrue(scheduler.pendingJobs.isEmpty)
    }

    func testShutdownWhenAsleepIsSafe() {
        controller.shutdown()
        XCTAssertEqual(controller.state, .asleep)
    }

    // MARK: Memory

    func testTimeoutClosureDoesNotRetainController() {
        weak var weakController: AwakeController?
        autoreleasepool {
            let c = AwakeController(preventer: preventer, scheduler: scheduler)
            weakController = c
            c.activate(for: .minutes(5))
        }
        XCTAssertNil(weakController)
        scheduler.fireAll()   // must not crash
    }

    // MARK: Presets

    func testEveryPresetActivatesCleanly() {
        for preset in Duration.presets {
            let p = SpySleepPreventer()
            let s = ManualScheduler()
            let c = AwakeController(preventer: p, scheduler: s)
            c.activate(for: preset)
            XCTAssertTrue(c.isAwake, "\(preset)")
            if let secs = preset.seconds {
                XCTAssertEqual(c.remaining, secs, "\(preset)")
                s.advance(by: secs)
                XCTAssertFalse(c.isAwake, "\(preset) should time out")
            } else {
                XCTAssertNil(c.remaining)
            }
        }
    }
}
