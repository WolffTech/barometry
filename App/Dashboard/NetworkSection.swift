import BarometryKit
import Charts
import SwiftUI

struct NetworkSection: View {
    let network: NetworkSample?
    let history: History<NetworkSample>

    @State private var hoverSlot: Int?

    var body: some View {
        let shown = hoverSlot.flatMap(history.element(inSlot:)) ?? network
        DashboardCard {
            CardHeader(title: "Network", detail: shown?.interface)
            HStack {
                rate(shown?.upload, label: "Upload", color: DashboardPalette.secondary)
                rate(shown?.download, label: "Download", color: DashboardPalette.primary)
            }
            chart
        }
    }

    private func rate(_ rate: ByteRate?, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(rate?.formatted() ?? "—")
                .font(.title3.weight(.medium).monospacedDigit())
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.callout)
            }
        }
        .frame(maxWidth: .infinity)
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
        .frame(height: 56)
    }
}
