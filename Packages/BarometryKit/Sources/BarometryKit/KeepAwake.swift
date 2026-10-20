// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import IOKit.pwr_mgt
import Observation

/// Keeps the display, and with it the system, from idle sleep while enabled, like
/// `caffeinate -d`, and optionally nudges the cursor so apps watching for user activity
/// see some. Starts disabled each launch, and stays off while the battery is at or below
/// `lowBatteryCutoff`.
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

    /// Whether the battery is at or below `lowBatteryCutoff`, which keeps Keep Awake off.
    public private(set) var isBlockedByLowBattery = false

    /// Charge at or below which Keep Awake turns off and can't be turned on while on battery
    /// power, or nil to ignore the battery.
    @ObservationIgnored public var lowBatteryCutoff: LowBatteryCutoff? {
        didSet {
            if lowBatteryCutoff != oldValue { applyLowBatteryCutoff() }
        }
    }

    /// The latest reading, or nil on Macs without a battery.
    @ObservationIgnored public var battery: BatterySample? {
        didSet {
            if battery != oldValue { applyLowBatteryCutoff() }
        }
    }

    @ObservationIgnored private var assertion: PowerAssertion?
    @ObservationIgnored private var cursorNudger: CursorNudger?

    public init() {}

    public func toggle() {
        setEnabled(!isEnabled)
    }

    /// Stays disabled if macOS refuses the assertion or the battery is too low.
    public func setEnabled(_ enabled: Bool) {
        let enabled = enabled && !isBlockedByLowBattery
        guard enabled != isEnabled else { return }
        assertion = enabled ? PowerAssertion(type: Self.assertionType, name: Self.assertionName) : nil
        isEnabled = assertion != nil
        updateCursorNudger()
    }

    private func applyLowBatteryCutoff() {
        let isBlocked = lowBatteryCutoff?.isReached(by: battery) ?? false
        if isBlocked != isBlockedByLowBattery { isBlockedByLowBattery = isBlocked }
        if isBlocked { setEnabled(false) }
    }

    private func updateCursorNudger() {
        if isEnabled, let interval = cursorNudgeInterval {
            cursorNudger = CursorNudger(every: interval.duration)
        } else {
            cursorNudger = nil
        }
    }
}

/// Battery charge, in whole percent, at or below which Keep Awake turns off while on
/// battery power.
public struct LowBatteryCutoff: Hashable, Sendable {
    public static let range = 5...50
    public static let `default` = LowBatteryCutoff(percent: 20)

    public let percent: Int

    /// Clamps to `range`.
    public init(percent: Int) {
        self.percent = min(max(percent, Self.range.lowerBound), Self.range.upperBound)
    }

    /// Compares the charge rounded the way it's shown, so the cutoff matches the displayed
    /// percentage. Charging, charged, or plugged-in batteries never reach it.
    func isReached(by battery: BatterySample?) -> Bool {
        guard let battery, case .discharging = battery.state else { return false }
        return Int((battery.charge.fraction * 100).rounded()) <= percent
    }
}
