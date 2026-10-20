// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import IOKit.pwr_mgt
import Testing
@testable import BarometryKit

@MainActor
struct KeepAwakeTests {
    /// Names of the assertions this process holds of `KeepAwake`'s type, as macOS reports them.
    private func heldAssertionNames() -> [String] {
        var byProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&byProcess) == kIOReturnSuccess,
              let processes = byProcess?.takeRetainedValue() as? [Int: [[String: Any]]]
        else { return [] }
        return (processes[Int(ProcessInfo.processInfo.processIdentifier)] ?? [])
            .filter { $0[kIOPMAssertionTypeKey] as? String == KeepAwake.assertionType }
            .compactMap { $0[kIOPMAssertionNameKey] as? String }
    }

    @Test func holdsDisplayAssertionOnlyWhileEnabled() {
        let keepAwake = KeepAwake()
        #expect(!heldAssertionNames().contains(KeepAwake.assertionName))

        keepAwake.toggle()
        #expect(keepAwake.isEnabled)
        #expect(heldAssertionNames().filter { $0 == KeepAwake.assertionName }.count == 1)

        // Enabling again must not stack a second assertion.
        keepAwake.setEnabled(true)
        #expect(heldAssertionNames().filter { $0 == KeepAwake.assertionName }.count == 1)

        keepAwake.toggle()
        #expect(!keepAwake.isEnabled)
        #expect(!heldAssertionNames().contains(KeepAwake.assertionName))
    }

    private func battery(_ percent: Double, _ state: BatterySample.State = .discharging(timeRemaining: nil)) -> BatterySample {
        BatterySample(charge: Percent(percent / 100), state: state)
    }

    @Test func turnsOffAtTheCutoffOnBatteryPower() {
        let keepAwake = KeepAwake()
        keepAwake.lowBatteryCutoff = .default
        keepAwake.battery = battery(21)
        keepAwake.setEnabled(true)
        #expect(keepAwake.isEnabled)

        keepAwake.battery = battery(20)
        #expect(!keepAwake.isEnabled)
        #expect(keepAwake.isBlockedByLowBattery)
    }

    @Test func cannotBeTurnedBackOnBelowTheCutoff() {
        let keepAwake = KeepAwake()
        keepAwake.lowBatteryCutoff = .default
        keepAwake.battery = battery(15)

        keepAwake.toggle()
        #expect(!keepAwake.isEnabled)
        #expect(!heldAssertionNames().contains(KeepAwake.assertionName))
    }

    @Test(arguments: [
        BatterySample.State.charging(timeToFull: nil),
        .charged,
        .notCharging,
    ])
    func ignoresTheCutoffWhilePluggedIn(state: BatterySample.State) {
        let keepAwake = KeepAwake()
        keepAwake.lowBatteryCutoff = .default
        keepAwake.battery = battery(10, state)

        keepAwake.setEnabled(true)
        #expect(keepAwake.isEnabled)
        keepAwake.setEnabled(false)
    }

    @Test func ignoresTheBatteryWithoutACutoffOrBattery() {
        let withoutCutoff = KeepAwake()
        withoutCutoff.battery = battery(5)
        withoutCutoff.setEnabled(true)
        #expect(withoutCutoff.isEnabled)
        withoutCutoff.setEnabled(false)

        let withoutBattery = KeepAwake()
        withoutBattery.lowBatteryCutoff = .default
        withoutBattery.setEnabled(true)
        #expect(withoutBattery.isEnabled)
        withoutBattery.setEnabled(false)
    }

    @Test func pluggingInLiftsTheBlock() {
        let keepAwake = KeepAwake()
        keepAwake.lowBatteryCutoff = .default
        keepAwake.battery = battery(15)
        #expect(keepAwake.isBlockedByLowBattery)

        keepAwake.battery = battery(15, .charging(timeToFull: nil))
        #expect(!keepAwake.isBlockedByLowBattery)
        keepAwake.setEnabled(true)
        #expect(keepAwake.isEnabled)
        keepAwake.setEnabled(false)
    }

    @Test func cutoffIsClampedToItsRange() {
        #expect(LowBatteryCutoff(percent: 0).percent == LowBatteryCutoff.range.lowerBound)
        #expect(LowBatteryCutoff(percent: 99).percent == LowBatteryCutoff.range.upperBound)
    }
}
