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
