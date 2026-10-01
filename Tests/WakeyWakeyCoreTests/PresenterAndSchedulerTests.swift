import XCTest
@testable import WakeyWakeyCore

final class MenuBarPresenterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: Symbol

    func testAsleepSymbol() {
        XCTAssertEqual(MenuBarPresenter.symbol(for: .asleep), MenuBarPresenter.asleepSymbol)
    }

    func testAwakeSymbolRegardlessOfDeadline() {
        XCTAssertEqual(MenuBarPresenter.symbol(for: .awake(until: nil)), MenuBarPresenter.awakeSymbol)
        XCTAssertEqual(MenuBarPresenter.symbol(for: .awake(until: now)), MenuBarPresenter.awakeSymbol)
    }

    func testSymbolsDiffer() {
        XCTAssertNotEqual(MenuBarPresenter.awakeSymbol, MenuBarPresenter.asleepSymbol)
    }

    // MARK: Tooltip

    func testAsleepTooltip() {
        XCTAssertEqual(MenuBarPresenter.tooltip(for: .asleep, now: now), "Wakey Wakey: off")
    }

    func testIndefiniteTooltip() {
        XCTAssertEqual(MenuBarPresenter.tooltip(for: .awake(until: nil), now: now), "Wakey Wakey: on indefinitely")
    }

    func testTimedTooltipShowsRemaining() {
        let until = now.addingTimeInterval(90 * 60)
        XCTAssertEqual(MenuBarPresenter.tooltip(for: .awake(until: until), now: now), "Wakey Wakey: on, 1h 30m left")
    }

    func testAllTooltipsContainAppName() {
        for state in [AwakeController.State.asleep, .awake(until: nil), .awake(until: now.addingTimeInterval(60))] {
            XCTAssertTrue(MenuBarPresenter.tooltip(for: state, now: now).contains(MenuBarPresenter.appName))
        }
    }

    // MARK: Status line

    func testAsleepStatusLine() {
        XCTAssertEqual(MenuBarPresenter.statusLine(for: .asleep, now: now), "Your Mac may sleep normally")
    }

    func testIndefiniteStatusLine() {
        XCTAssertEqual(MenuBarPresenter.statusLine(for: .awake(until: nil), now: now), "Keeping your Mac awake indefinitely")
    }

    func testTimedStatusLine() {
        let until = now.addingTimeInterval(5 * 60)
        XCTAssertEqual(MenuBarPresenter.statusLine(for: .awake(until: until), now: now), "Keeping your Mac awake — 5m left")
    }

    // MARK: Toggle title

    func testToggleTitles() {
        XCTAssertEqual(MenuBarPresenter.toggleMenuTitle(isAwake: false), "Turn On")
        XCTAssertEqual(MenuBarPresenter.toggleMenuTitle(isAwake: true), "Turn Off")
    }

    // MARK: Remaining label

    func testWholeMinutes() {
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now.addingTimeInterval(5 * 60), now: now), "5m")
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now.addingTimeInterval(59 * 60), now: now), "59m")
    }

    func testWholeHours() {
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now.addingTimeInterval(3600), now: now), "1h")
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now.addingTimeInterval(5 * 3600), now: now), "5h")
    }

    func testHoursAndMinutes() {
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now.addingTimeInterval(3600 + 60), now: now), "1h 1m")
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now.addingTimeInterval(2 * 3600 + 45 * 60), now: now), "2h 45m")
    }

    func testPartialMinutesRoundUp() {
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now.addingTimeInterval(61), now: now), "2m")
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now.addingTimeInterval(3599), now: now), "1h")
    }

    func testUnderAMinute() {
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now.addingTimeInterval(1), now: now), "1m")
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now, now: now), "<1m")
    }

    func testPastDeadlineIsUnderAMinute() {
        XCTAssertEqual(MenuBarPresenter.remainingLabel(until: now.addingTimeInterval(-500), now: now), "<1m")
    }

    func testEveryPresetHasAClearLabelAtStart() {
        let expected: [Duration: String] = [
            .minutes(5): "5m", .minutes(10): "10m", .minutes(15): "15m", .minutes(30): "30m",
            .minutes(60): "1h", .minutes(120): "2h", .minutes(300): "5h",
        ]
        for (duration, label) in expected {
            let until = now.addingTimeInterval(duration.seconds!)
            XCTAssertEqual(MenuBarPresenter.remainingLabel(until: until, now: now), label, "\(duration)")
        }
    }
}

final class TimerSchedulerTests: XCTestCase {
    func testWorkRunsAfterDelay() {
        let done = expectation(description: "fired")
        _ = TimerScheduler().schedule(after: 0.05) { done.fulfill() }
        wait(for: [done], timeout: 1)
    }

    func testCancelPreventsWork() {
        let notFired = expectation(description: "not fired")
        notFired.isInverted = true
        let token = TimerScheduler().schedule(after: 0.05) { notFired.fulfill() }
        token.cancel()
        wait(for: [notFired], timeout: 0.3)
    }

    func testWorkRunsOnlyOnce() {
        let fired = expectation(description: "fired")
        var count = 0
        _ = TimerScheduler().schedule(after: 0.05) { count += 1; fired.fulfill() }
        wait(for: [fired], timeout: 1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(count, 1)
    }

    func testNegativeDelayStillFires() {
        let done = expectation(description: "fired")
        _ = TimerScheduler().schedule(after: -5) { done.fulfill() }
        wait(for: [done], timeout: 1)
    }

    func testNowIsCurrent() {
        let before = Date()
        let now = TimerScheduler().now()
        XCTAssertGreaterThanOrEqual(now, before)
        XCTAssertLessThan(now.timeIntervalSince(before), 1)
    }
}

final class ManualSchedulerTests: XCTestCase {
    func testAdvanceFiresDueJobsInOrder() {
        let s = ManualScheduler()
        var order: [Int] = []
        _ = s.schedule(after: 30) { order.append(2) }
        _ = s.schedule(after: 10) { order.append(1) }
        _ = s.schedule(after: 100) { order.append(3) }
        s.advance(by: 50)
        XCTAssertEqual(order, [1, 2])
        XCTAssertEqual(s.pendingJobs.count, 1)
    }

    func testClockIsCorrectInsideFiredJob() {
        let s = ManualScheduler()
        let start = s.now()
        var seen: Date?
        _ = s.schedule(after: 10) { seen = s.now() }
        s.advance(by: 60)
        XCTAssertEqual(seen, start.addingTimeInterval(10))
        XCTAssertEqual(s.now(), start.addingTimeInterval(60))
    }

    func testCancelledJobDoesNotFire() {
        let s = ManualScheduler()
        var ran = false
        let token = s.schedule(after: 1) { ran = true }
        token.cancel()
        s.advance(by: 10)
        XCTAssertFalse(ran)
    }

    func testJobFiresOnlyOnce() {
        let s = ManualScheduler()
        var count = 0
        _ = s.schedule(after: 1) { count += 1 }
        s.advance(by: 10)
        s.advance(by: 10)
        s.fireAll()
        XCTAssertEqual(count, 1)
    }
}
