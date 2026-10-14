// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing
@testable import BarometryKit

struct SensorTests {
    private let locale = Locale(identifier: "en_US")

    @Test func meanTemperatureDropsImplausibleReadings() {
        let mean = SensorSample.meanTemperature([40, 50, 0, -3, 999])

        #expect(mean == Temperature(celsius: 45))
    }

    @Test func meanTemperatureIsNilWithoutValidReadings() {
        #expect(SensorSample.meanTemperature([0, 0]) == nil)
    }

    @Test func averageFrequencyWeightsActiveStatesByResidency() {
        let table = [Frequency(megahertz: 1000), Frequency(megahertz: 2000), Frequency(megahertz: 3000)]
        let states: [(name: String, residency: Int64)] = [("IDLE", 900), ("V0P2", 50), ("V1P1", 0), ("V2P0", 50)]

        #expect(DVFS.averageFrequency(states: states, table: table) == Frequency(megahertz: 2000))
    }

    @Test func averageFrequencyIgnoresStatesBeyondTable() {
        let table = [Frequency(megahertz: 338)]
        let states: [(name: String, residency: Int64)] = [("OFF", 10), ("P1", 5), ("P2", 5)]

        #expect(DVFS.averageFrequency(states: states, table: table) == Frequency(megahertz: 338))
    }

    @Test func averageFrequencyIsNilWhenIdle() {
        let states: [(name: String, residency: Int64)] = [("IDLE", 100), ("V0P1", 0)]

        #expect(DVFS.averageFrequency(states: states, table: [Frequency(megahertz: 1000)]) == nil)
    }

    @Test func frequencyTableReadsFrequencyFromEachPairAndDropsOff() {
        // (0 Hz, 1 V), (744 MHz, 2 V), (2748 MHz in kHz, 3 V)
        let words: [UInt32] = [0, 1, 744_000_000, 2, 2_748_000, 3]
        let bytes = words.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded: word >> ($0 * 8)) } }

        let table = DVFS.frequencyTable(fromVoltageStates: bytes)

        #expect(table == [Frequency(megahertz: 744), Frequency(megahertz: 2748)])
    }

    @Test func decodesSMCDataTypes() {
        let float = Float(43.5).bitPattern
        let floatBytes = (0..<4).map { UInt8(truncatingIfNeeded: float >> ($0 * 8)) }

        #expect(SMC.decode(floatBytes, type: "flt ") == 43.5)
        #expect(SMC.decode([2], type: "ui8 ") == 2)
        #expect(SMC.decode([0x01, 0x00], type: "ui16") == 256)
        #expect(SMC.decode([0x2B, 0x80], type: "sp78") == 43.5)
        #expect(SMC.decode([0x00, 0x0A], type: "fpe2") == 2.5)
        #expect(SMC.decode([1, 2], type: "ch8*") == nil)
    }

    @Test func fourCCRoundTrips() {
        #expect(SMC.string(fromFourCC: SMC.fourCC("PSTR")) == "PSTR")
    }

    @Test(arguments: [(43.6, "44°"), (-0.4, "0°")])
    func formatsCelsius(celsius: Double, expected: String) {
        #expect(Temperature(celsius: celsius).formatted() == expected)
    }

    @Test func formatsFahrenheit() {
        #expect(Temperature(celsius: 100).formatted(in: .fahrenheit) == "212°")
    }

    @Test(arguments: [(3.608, "3.6 W"), (24.4, "24 W"), (9.96, "10 W")])
    func formatsPower(watts: Double, expected: String) {
        #expect(Power(watts: watts).formatted(locale: locale) == expected)
    }

    @Test(arguments: [(3_150_000_000.0, "3.15 GHz"), (400_000_000, "0.4 GHz"), (2_000_000_000, "2 GHz")])
    func formatsFrequency(hertz: Double, expected: String) {
        #expect(Frequency(hertz: hertz).formatted(locale: locale) == expected)
    }

    @Test func idleFanIsNotSpinning() {
        #expect(!Fan(id: 0, rpm: 0, maximumRPM: 6800).isSpinning)
        #expect(Fan(id: 0, rpm: 2317, maximumRPM: 6800).isSpinning)
    }
}
