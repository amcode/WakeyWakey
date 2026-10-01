import XCTest
@testable import WakeyWakeyCore

final class DurationTests: XCTestCase {
    // MARK: Seconds

    func testIndefiniteHasNoSeconds() {
        XCTAssertNil(Duration.indefinite.seconds)
    }

    func testMinutesConvertToSeconds() {
        XCTAssertEqual(Duration.minutes(1).seconds, 60)
        XCTAssertEqual(Duration.minutes(30).seconds, 1800)
        XCTAssertEqual(Duration.minutes(300).seconds, 18000)
    }

    // MARK: Display names

    func testIndefiniteName() {
        XCTAssertEqual(Duration.indefinite.displayName, "Indefinitely")
    }

    func testMinuteNames() {
        XCTAssertEqual(Duration.minutes(1).displayName, "1 minute")
        XCTAssertEqual(Duration.minutes(5).displayName, "5 minutes")
        XCTAssertEqual(Duration.minutes(45).displayName, "45 minutes")
    }

    func testHourNames() {
        XCTAssertEqual(Duration.minutes(60).displayName, "1 hour")
        XCTAssertEqual(Duration.minutes(120).displayName, "2 hours")
        XCTAssertEqual(Duration.minutes(300).displayName, "5 hours")
    }

    func testNonWholeHoursShownInMinutes() {
        XCTAssertEqual(Duration.minutes(90).displayName, "90 minutes")
    }

    func testPresetNamesAreUnique() {
        let names = Duration.presets.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
    }

    // MARK: Raw minutes round trip

    func testIndefiniteRawIsZero() {
        XCTAssertEqual(Duration.indefinite.rawMinutes, 0)
        XCTAssertEqual(Duration(rawMinutes: 0), .indefinite)
    }

    func testNegativeRawIsIndefinite() {
        XCTAssertEqual(Duration(rawMinutes: -5), .indefinite)
    }

    func testMinutesRawRoundTrip() {
        for preset in Duration.presets {
            XCTAssertEqual(Duration(rawMinutes: preset.rawMinutes), preset)
        }
    }

    // MARK: Presets

    func testPresetsStartWithIndefinite() {
        XCTAssertEqual(Duration.presets.first, .indefinite)
    }

    func testTimedPresetsAreAscending() {
        let timed = Duration.presets.compactMap(\.seconds)
        XCTAssertEqual(timed, timed.sorted())
        XCTAssertEqual(timed.count, Duration.presets.count - 1)
    }

    func testPresetsMatchOriginalApp() {
        XCTAssertEqual(Duration.presets, [
            .indefinite, .minutes(5), .minutes(10), .minutes(15), .minutes(30),
            .minutes(60), .minutes(120), .minutes(300),
        ])
    }

    // MARK: Codable / Hashable

    func testCodableRoundTrip() throws {
        for preset in Duration.presets {
            let data = try JSONEncoder().encode(preset)
            XCTAssertEqual(try JSONDecoder().decode(Duration.self, from: data), preset)
        }
    }

    func testHashable() {
        let set: Set<Duration> = [.minutes(5), .minutes(5), .indefinite]
        XCTAssertEqual(set.count, 2)
    }
}

final class SettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: Settings!

    override func setUp() {
        super.setUp()
        defaults = makeTestDefaults()
        settings = Settings(defaults: defaults)
    }

    // MARK: Defaults

    func testDefaultActivateOnLaunchIsOff() {
        XCTAssertFalse(settings.activateOnLaunch)
    }

    func testDefaultDurationIsIndefinite() {
        XCTAssertEqual(settings.defaultDuration, .indefinite)
    }

    func testDefaultPreventDisplaySleepIsOn() {
        XCTAssertTrue(settings.preventDisplaySleep)
    }

    // MARK: Persistence

    func testActivateOnLaunchRoundTrips() {
        settings.activateOnLaunch = true
        XCTAssertTrue(Settings(defaults: defaults).activateOnLaunch)
        settings.activateOnLaunch = false
        XCTAssertFalse(Settings(defaults: defaults).activateOnLaunch)
    }

    func testDefaultDurationRoundTrips() {
        for preset in Duration.presets {
            settings.defaultDuration = preset
            XCTAssertEqual(Settings(defaults: defaults).defaultDuration, preset)
        }
    }

    func testPreventDisplaySleepRoundTrips() {
        settings.preventDisplaySleep = false
        XCTAssertFalse(Settings(defaults: defaults).preventDisplaySleep)
        settings.preventDisplaySleep = true
        XCTAssertTrue(Settings(defaults: defaults).preventDisplaySleep)
    }

    // MARK: Robustness

    func testCorruptDurationFallsBackToIndefinite() {
        defaults.set(-100, forKey: Settings.Key.defaultDurationMinutes)
        XCTAssertEqual(settings.defaultDuration, .indefinite)
    }

    func testNonPresetDurationIsStillHonoured() {
        defaults.set(42, forKey: Settings.Key.defaultDurationMinutes)
        XCTAssertEqual(settings.defaultDuration, .minutes(42))
    }

    func testSeparateSuitesDoNotShareState() {
        let other = Settings(defaults: makeTestDefaults("other"))
        settings.activateOnLaunch = true
        XCTAssertFalse(other.activateOnLaunch)
    }
}
