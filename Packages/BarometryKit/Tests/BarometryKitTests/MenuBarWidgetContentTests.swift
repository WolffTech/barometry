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
        temperatureUnit: TemperatureUnit = .celsius,
        isKeepingAwake: Bool = false
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
            isKeepingAwake: isKeepingAwake,
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

    @Test func missingBatteryShowsEmptyGaugeWithDashes() {
        #expect(content(.battery) == .battery(BatteryIndicator(fraction: 0, status: .discharging(timeRemaining: "—"), charge: "—")))
    }

    @Test func batteryShowsTimeRemainingOverCharge() {
        let battery = BatterySample(charge: Percent(0.44), state: .discharging(timeRemaining: .seconds(142 * 60)))

        #expect(content(.battery, battery: battery) == .battery(BatteryIndicator(fraction: 0.44, status: .discharging(timeRemaining: "2:22"), charge: "44%")))
    }

    @Test(arguments: [
        (BatterySample.State.discharging(timeRemaining: nil), BatteryIndicator.Status.discharging(timeRemaining: "–:––")),
        (.charging(timeToFull: .seconds(30 * 60)), .charging(timeToFull: "0:30")),
        (.charging(timeToFull: nil), .charging(timeToFull: "–:––")),
        (.charged, .charged),
        (.notCharging, .paused),
    ])
    func batteryStatus(state: BatterySample.State, expected: BatteryIndicator.Status) {
        #expect(BatteryIndicator(BatterySample(charge: Percent(0.8), state: state), locale: locale).status == expected)
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

    @Test func batteryIsBadgedWhileKeepingAwake() {
        let battery = BatterySample(charge: Percent(0.44), state: .discharging(timeRemaining: .seconds(142 * 60)))

        #expect(content(.battery, battery: battery, isKeepingAwake: true) == .battery(BatteryIndicator(fraction: 0.44, status: .discharging(timeRemaining: "2:22"), charge: "44%", badge: .keepAwake)))
    }

    @Test func missingBatteryIsStillBadgedWhileKeepingAwake() {
        #expect(content(.battery, isKeepingAwake: true) == .battery(BatteryIndicator(fraction: 0, status: .discharging(timeRemaining: "—"), charge: "—", badge: .keepAwake)))
    }

    @Test func textBatteryIsBadgedWhileKeepingAwake() {
        let battery = BatterySample(charge: Percent(0.87), state: .notCharging)

        #expect(content(.battery, style: .text, battery: battery, isKeepingAwake: true) == .readouts([
            Readout(label: "BAT", value: "87%", widthTemplate: "⚡︎100%", badge: .keepAwake),
        ]))
    }

    @Test func onlyBatteryIsBadged() {
        let history = [CPULoad(user: Percent(0.2), system: Percent(0.02))]

        #expect(content(.cpu, style: .text, cpuHistory: history, isKeepingAwake: true) == .readouts([Readout(label: "CPU", value: "22%", widthTemplate: "100%")]))
    }
}
