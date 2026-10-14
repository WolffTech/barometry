// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import IOKit.pwr_mgt
import Observation

/// Keeps the display, and with it the system, from idle sleep while enabled, like
/// `caffeinate -d`, and optionally nudges the cursor so apps watching for user activity
/// see some. Starts disabled each launch.
@MainActor
@Observable
public final class KeepAwake {
    static let assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep
    static let assertionName = "Barometry Keep Awake"

    public private(set) var isEnabled = false

    /// How long input stays idle before the cursor is nudged while enabled, or nil to leave
    /// the cursor alone.
    @ObservationIgnored public var cursorNudgeInterval: CursorNudgeInterval? {
        didSet {
            if cursorNudgeInterval != oldValue { updateCursorNudger() }
        }
    }

    @ObservationIgnored private var assertion: PowerAssertion?
    @ObservationIgnored private var cursorNudger: CursorNudger?

    public init() {}

    public func toggle() {
        setEnabled(!isEnabled)
    }

    /// Stays disabled if macOS refuses the assertion.
    public func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        assertion = enabled ? PowerAssertion(type: Self.assertionType, name: Self.assertionName) : nil
        isEnabled = assertion != nil
        updateCursorNudger()
    }

    private func updateCursorNudger() {
        if isEnabled, let interval = cursorNudgeInterval {
            cursorNudger = CursorNudger(every: interval.duration)
        } else {
            cursorNudger = nil
        }
    }
}
