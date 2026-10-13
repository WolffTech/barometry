import IOKit.pwr_mgt
import Observation

/// Keeps the display, and with it the system, from idle sleep while enabled, like
/// `caffeinate -d`. Starts disabled each launch.
@MainActor
@Observable
public final class KeepAwake {
    static let assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep
    static let assertionName = "Barometry Keep Awake"

    public private(set) var isEnabled = false

    @ObservationIgnored private var assertion: PowerAssertion?

    public init() {}

    public func toggle() {
        setEnabled(!isEnabled)
    }

    /// Stays disabled if macOS refuses the assertion.
    public func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        assertion = enabled ? PowerAssertion(type: Self.assertionType, name: Self.assertionName) : nil
        isEnabled = assertion != nil
    }
}
