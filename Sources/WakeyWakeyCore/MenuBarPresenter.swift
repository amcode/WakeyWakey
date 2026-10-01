import Foundation

/// Pure presentation logic for the menu bar. No AppKit, so it's unit-testable.
public enum MenuBarPresenter {
    public static let appName = "Wakey Wakey"
    public static let awakeSymbol = "eye"
    public static let asleepSymbol = "eye.slash"

    public static func symbol(for state: AwakeController.State) -> String {
        switch state {
        case .asleep: return asleepSymbol
        case .awake: return awakeSymbol
        }
    }

    public static func tooltip(for state: AwakeController.State, now: Date) -> String {
        switch state {
        case .asleep:
            return "\(appName): off"
        case .awake(let until):
            guard let until else { return "\(appName): on indefinitely" }
            return "\(appName): on, \(remainingLabel(until: until, now: now)) left"
        }
    }

    /// The disabled first line of the menu.
    public static func statusLine(for state: AwakeController.State, now: Date) -> String {
        switch state {
        case .asleep:
            return "Your Mac may sleep normally"
        case .awake(let until):
            guard let until else { return "Keeping your Mac awake indefinitely" }
            return "Keeping your Mac awake — \(remainingLabel(until: until, now: now)) left"
        }
    }

    public static func toggleMenuTitle(isAwake: Bool) -> String {
        isAwake ? "Turn Off" : "Turn On"
    }

    /// "4h 59m", "59m", "<1m".
    public static func remainingLabel(until: Date, now: Date) -> String {
        let secs = max(0, until.timeIntervalSince(now))
        let totalMinutes = Int((secs / 60).rounded(.up))
        if totalMinutes < 1 { return "<1m" }
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
