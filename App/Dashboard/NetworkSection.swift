import BarometryKit
import Charts
import SwiftUI

struct NetworkSection: View {
    let network: NetworkSample?
    let history: History<NetworkSample>
    /// Display names, such as "Wi-Fi", keyed by BSD name.
    let interfaceNames: [String: String]
    @Binding var isExpanded: Bool

    @State private var hoverSlot: Int?

    var body: some View {
        GlanceRow(
            title: "Network",
            summary: network.flatMap { summary(interfaceNames[$0.interface], $0.interface) },
            symbol: "arrow.up.arrow.down",
            tint: .cyan,
            isExpanded: $isExpanded
        ) {
            Sparkline(history, color: .cyan, in: 0...peak) { $0.upload.bytesPerSecond + $0.download.bytesPerSecond }
        } value: {
            VStack(alignment: .trailing, spacing: 0) {
                Text("↑ \(network?.upload.formatted() ?? missingValue)")
                Text("↓ \(network?.download.formatted() ?? missingValue)")
            }
            .font(.caption.weight(.semibold))
        } detail: {
            detail
        }
    }

    /// Largest combined rate in the history, with a floor so idle traffic stays near the baseline.
    private var peak: Double {
        max(history.map { $0.upload.bytesPerSecond + $0.download.bytesPerSecond }.max() ?? 0, 1_000)
    }

    private var detail: some View {
        // While hovering, the legend shows the hovered sample instead of the latest one.
        let shown = hoverSlot.flatMap(history.element(inSlot:)) ?? network
        return VStack(spacing: 6) {
            chart
            LegendRow(color: DashboardPalette.secondary, label: "Upload", value: shown?.upload.formatted() ?? missingValue)
            LegendRow(color: DashboardPalette.primary, label: "Download", value: shown?.download.formatted() ?? missingValue)
        }
    }

    /// Upload grows up from the center line and download grows down, on one shared scale.
    private var chart: some View {
        let peak = max(history.map { max($0.upload.bytesPerSecond, $0.download.bytesPerSecond) }.max() ?? 0, 1_000)
        return Chart {
            ForEach(history.slotted, id: \.slot) { slot, sample in
                BarMark(x: .value("Time", slot), y: .value("Rate", sample.upload.bytesPerSecond), width: .fixed(1.5))
                    .foregroundStyle(DashboardPalette.secondary)
                BarMark(x: .value("Time", slot), y: .value("Rate", -sample.download.bytesPerSecond), width: .fixed(1.5))
                    .foregroundStyle(DashboardPalette.primary)
            }
            RuleMark(y: .value("Rate", 0))
                .foregroundStyle(DashboardPalette.track)
                .lineStyle(StrokeStyle(lineWidth: 1))
            if let hoverSlot, history.element(inSlot: hoverSlot) != nil {
                RuleMark(x: .value("Time", hoverSlot))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: history.slotDomain)
        .chartYScale(domain: -peak...peak)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartHoverSlot($hoverSlot)
        .frame(height: 40)
    }
}
