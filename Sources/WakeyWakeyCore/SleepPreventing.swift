import Foundation

/// Abstracts the OS "don't sleep" assertion so the logic can be tested without IOKit.
public protocol SleepPreventing: AnyObject {
    /// Whether an assertion is currently held.
    var isPreventingSleep: Bool { get }
    /// Take out the assertion. Returns false if the OS refused.
    @discardableResult
    func preventSleep(reason: String) -> Bool
    /// Release the assertion. Safe to call when none is held.
    func allowSleep()
}
