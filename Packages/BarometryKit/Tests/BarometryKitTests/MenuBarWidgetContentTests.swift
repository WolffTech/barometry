import Foundation
import Testing
@testable import BarometryKit

struct MenuBarWidgetContentTests {
    private let locale = Locale(identifier: "en_US")

    private func content(
        _ module: MenuBarModule,
        style: MenuBarStyle = .graphical,
        cpuHistory: [CPULoad] = [],
        memory: MemorySample? = nil,
        network: NetworkSample? = nil,
        battery: BatterySample? = nil,
        sensors: SensorSample? = nil,
        temperatureUnit: TemperatureUnit = .celsius
    ) -> MenuBarWidgetContent {
        .make(
            module: module,
            style: style,
            cpuHistory: cpuHistory,
            gpuHistory: [],
            memory: memory,
            network: network,
            battery: battery,
            sensors: sensors,
            temperatureUnit: temperatureUnit,
            locale: locale
        )
    }

    @Test func cpuGraphKeepsMostRecentBars() {
        let history = (0..<30).map { CPULoad(user: Percent(Double($0) / 100), system: .zero) }

        guard case .graph(let values) = content(.cpu, cpuHistory: history) else {
            Issue.record("Expected a graph")
            return
        }

        #expect(values.count == MenuBarWidgetContent.graphBarCount)
        #expect(values.first == 0.10)
        #expect(values.last == 0.29)
    }

    @Test func networkShowsUploadOverDownload() {
        let network = NetworkSample(interface: "en0", upload: ByteRate(bytesPerSecond: 22_000), download: ByteRate(bytesPerSecond: 44_000))

        #expect(content(.network, network: network) == .lines(top: "22 KB/s", bottom: "44 KB/s", glyphs: LineGlyphs(top: "↑", bottom: "↓"), widthTemplate: "888 KB/s"))
    }

    @Test func sensorsShowTemperatureOverPower() {
        let sensors = SensorSample(cpuTemperature: Temperature(celsius: 43.6), gpuTemperature: nil, systemPower: Power(watts: 3.61), fans: [])

        guard case .lines(let top, let bottom, _, _) = content(.sensors, sensors: sensors) else {
            Issue.record("Expected lines")
            return
        }

        #expect(top == "44°")
        #expect(bottom == "3.6 W")
    }

    @Test func sensorsUseChosenTemperatureUnit() {
        let sensors = SensorSample(cpuTemperature: Temperature(celsius: 50), gpuTemperature: nil, systemPower: nil, fans: [])

        guard case .lines(let top, _, _, _) = content(.sensors, sensors: sensors, temperatureUnit: .fahrenheit) else {
            Issue.record("Expected lines")
            return
        }

        #expect(top == "122°")
    }

    @Test func missingReadingsShowDashes() {
        guard case .lines(let top, let bottom, _, _) = content(.battery) else {
            Issue.record("Expected lines")
            return
        }

        #expect(top == "—")
        #expect(bottom == "—")
    }

    @Test func batteryShowsTimeRemainingOverCharge() {
        let battery = BatterySample(charge: Percent(0.44), state: .discharging(timeRemaining: .seconds(142 * 60)))

        guard case .lines(let top, let bottom, _, _) = content(.battery, battery: battery) else {
            Issue.record("Expected lines")
            return
        }

        #expect(top == "2:22")
        #expect(bottom == "44%")
    }

    @Test(arguments: [
        (BatterySample.State.discharging(timeRemaining: nil), "–:––"),
        (.charging(timeToFull: .seconds(30 * 60)), "⚡︎0:30"),
        (.charging(timeToFull: nil), "⚡︎"),
        (.charged, "Full"),
        (.notCharging, "AC"),
    ])
    func batteryStatusLine(state: BatterySample.State, expected: String) {
        #expect(MenuBarWidgetContent.batteryStatus(state, locale: locale) == expected)
    }

    @Test func textCPUShowsLatestLoad() {
        let history = [CPULoad(user: Percent(0.5), system: .zero), CPULoad(user: Percent(0.2), system: Percent(0.02))]

        #expect(content(.cpu, style: .text, cpuHistory: history) == .readouts([Readout(label: "CPU", value: "22%", widthTemplate: "100%")]))
    }

    @Test func textSensorsSplitIntoTemperatureAndPower() {
        let sensors = SensorSample(cpuTemperature: Temperature(celsius: 50), gpuTemperature: nil, systemPower: Power(watts: 9.41), fans: [])

        #expect(content(.sensors, style: .text, sensors: sensors, temperatureUnit: .fahrenheit) == .readouts([
            Readout(label: "TEMP", value: "122°", widthTemplate: "188°"),
            Readout(label: "PWR", value: "9.4 W", widthTemplate: "88.8 W"),
        ]))
    }

    @Test(arguments: [
        (BatterySample.State.charging(timeToFull: nil), "⚡︎87%"),
        (.discharging(timeRemaining: .seconds(60)), "87%"),
        (.notCharging, "87%"),
    ])
    func textBatteryMarksCharging(state: BatterySample.State, expected: String) {
        let battery = BatterySample(charge: Percent(0.87), state: state)

        guard case .readouts(let readouts) = content(.battery, style: .text, battery: battery) else {
            Issue.record("Expected readouts")
            return
        }

        #expect(readouts.map(\.value) == [expected])
    }

    @Test(arguments: [MenuBarModule.cpu, .gpu, .memory, .battery])
    func textMissingReadingsShowDashes(module: MenuBarModule) {
        guard case .readouts(let readouts) = content(module, style: .text) else {
            Issue.record("Expected readouts")
            return
        }

        #expect(readouts.map(\.value) == ["—"])
    }

    @Test func networkLooksTheSameInBothStyles() {
        let network = NetworkSample(interface: "en0", upload: ByteRate(bytesPerSecond: 22_000), download: ByteRate(bytesPerSecond: 44_000))

        #expect(content(.network, style: .text, network: network) == content(.network, network: network))
    }
}
