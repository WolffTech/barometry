import Foundation
import Testing
@testable import BarometryKit

struct MenuBarWidgetContentTests {
    private let locale = Locale(identifier: "en_US")

    private func content(
        _ module: MenuBarModule,
        cpuHistory: [CPULoad] = [],
        network: NetworkSample? = nil,
        battery: BatterySample? = nil
    ) -> MenuBarWidgetContent {
        .make(module: module, cpuHistory: cpuHistory, memory: nil, network: network, battery: battery, locale: locale)
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

        #expect(content(.network, network: network) == .lines(top: "↑ 22 KB/s", bottom: "↓ 44 KB/s", widthTemplate: "↑ 888 KB/s"))
    }

    @Test func missingReadingsShowDashes() {
        guard case .lines(let top, let bottom, _) = content(.battery) else {
            Issue.record("Expected lines")
            return
        }

        #expect(top == "—")
        #expect(bottom == "—")
    }

    @Test func batteryShowsTimeRemainingOverCharge() {
        let battery = BatterySample(charge: Percent(0.44), state: .discharging(timeRemaining: .seconds(142 * 60)))

        guard case .lines(let top, let bottom, _) = content(.battery, battery: battery) else {
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
}
