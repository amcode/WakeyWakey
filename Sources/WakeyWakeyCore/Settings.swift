import Foundation

/// How long to stay awake for. `.indefinite` means until switched off.
public enum Duration: Equatable, Hashable, Codable {
    case indefinite
    case minutes(Int)

    /// The options offered in the menu, in display order.
    public static let presets: [Duration] = [
        .indefinite,
        .minutes(5), .minutes(10), .minutes(15), .minutes(30),
        .minutes(60), .minutes(120), .minutes(300),
    ]

    public var seconds: TimeInterval? {
        switch self {
        case .indefinite: return nil
        case .minutes(let m): return TimeInterval(m) * 60
        }
    }

    /// "Indefinitely", "5 minutes", "1 hour", "2 hours".
    public var displayName: String {
        switch self {
        case .indefinite:
            return "Indefinitely"
        case .minutes(let m) where m % 60 == 0:
            let h = m / 60
            return h == 1 ? "1 hour" : "\(h) hours"
        case .minutes(let m):
            return m == 1 ? "1 minute" : "\(m) minutes"
        }
    }

    // Stored in defaults as an Int: 0 = indefinite, otherwise minutes.
    public var rawMinutes: Int {
        switch self {
        case .indefinite: return 0
        case .minutes(let m): return m
        }
    }

    public init(rawMinutes: Int) {
        self = rawMinutes > 0 ? .minutes(rawMinutes) : .indefinite
    }
}

/// User-tunable settings, persisted in `UserDefaults`. Injectable suite so tests stay isolated.
public final class Settings {
    enum Key {
        static let activateOnLaunch = "activateOnLaunch"
        static let defaultDurationMinutes = "defaultDurationMinutes"
        static let preventDisplaySleep = "preventDisplaySleep"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Start keeping the Mac awake as soon as the app launches.
    public var activateOnLaunch: Bool {
        get { defaults.bool(forKey: Key.activateOnLaunch) }
        set { defaults.set(newValue, forKey: Key.activateOnLaunch) }
    }

    /// Duration used by a plain left-click on the icon.
    public var defaultDuration: Duration {
        get { Duration(rawMinutes: defaults.integer(forKey: Key.defaultDurationMinutes)) }
        set { defaults.set(newValue.rawMinutes, forKey: Key.defaultDurationMinutes) }
    }

    /// Keep the display on too (not just the system). Defaults to on, matching what people expect.
    public var preventDisplaySleep: Bool {
        get { defaults.object(forKey: Key.preventDisplaySleep) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.preventDisplaySleep) }
    }
}
