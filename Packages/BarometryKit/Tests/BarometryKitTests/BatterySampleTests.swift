// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import IOKit.ps
import Testing
@testable import BarometryKit

struct BatterySampleTests {
    private func description(_ overrides: [String: Any]) -> [String: Any] {
        let base: [String: Any] = [
            kIOPSTypeKey: kIOPSInternalBatteryType,
            kIOPSIsPresentKey: true,
            kIOPSCurrentCapacityKey: 44,
            kIOPSMaxCapacityKey: 100,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
            kIOPSIsChargingKey: false,
        ]
        return base.merging(overrides) { $1 }
    }

    @Test func dischargingReportsTimeRemaining() {
        let sample = BatterySample(powerSourceDescription: description([kIOPSTimeToEmptyKey: 142]))

        #expect(sample == BatterySample(charge: Percent(0.44), state: .discharging(timeRemaining: .seconds(142 * 60))))
    }

    @Test func calculatingEstimateIsNil() {
        let sample = BatterySample(powerSourceDescription: description([kIOPSTimeToEmptyKey: -1]))

        #expect(sample?.state == .discharging(timeRemaining: nil))
    }

    @Test func chargingReportsTimeToFull() {
        let sample = BatterySample(powerSourceDescription: description([
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSIsChargingKey: true,
            kIOPSTimeToFullChargeKey: 30,
        ]))

        #expect(sample?.state == .charging(timeToFull: .seconds(30 * 60)))
    }

    @Test func fullOnPowerIsCharged() {
        let sample = BatterySample(powerSourceDescription: description([
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSCurrentCapacityKey: 100,
        ]))

        #expect(sample?.state == .charged)
    }

    @Test func heldChargeOnPowerIsNotCharging() {
        let sample = BatterySample(powerSourceDescription: description([
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSCurrentCapacityKey: 80,
        ]))

        #expect(sample?.state == .notCharging)
    }

    @Test func ignoresExternalPowerSources() {
        #expect(BatterySample(powerSourceDescription: description([kIOPSTypeKey: kIOPSUPSType])) == nil)
    }
}

struct BatteryHealthTests {
    @Test func readsTopLevelCapacities() {
        let health = BatteryHealth(registry: ["CycleCount": 312, "DesignCapacity": 5000, "AppleRawMaxCapacity": 4500])

        #expect(health == BatteryHealth(cycleCount: 312, maximumCapacity: Percent(0.9)))
    }

    @Test func fallsBackToBatteryData() {
        let health = BatteryHealth(registry: [
            "CycleCount": 18,
            "BatteryData": ["DesignCapacity": 6000, "NominalChargeCapacity": 5700],
        ])

        #expect(health == BatteryHealth(cycleCount: 18, maximumCapacity: Percent(0.95)))
    }

    @Test func missingCapacityIsNil() {
        #expect(BatteryHealth(registry: ["CycleCount": 18]) == nil)
    }
}
