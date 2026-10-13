import BarometryKit
import SwiftUI

struct NetworkSection: View {
    let network: NetworkSample?
    let history: History<NetworkSample>
    /// Display names, such as "Wi-Fi", keyed by BSD name.
    let interfaceNames: [String: String]

    var body: some View {
        GlanceRow(section: .network, summary: network.flatMap { summary(interfaceNames[$0.interface], $0.interface) }) {
            Sparkline(history, color: DashboardSection.network.tint, in: 0...peak) { $0.upload.bytesPerSecond + $0.download.bytesPerSecond }
        } value: {
            VStack(alignment: .trailing, spacing: 0) {
                Text("↑ \(network?.upload.formatted() ?? missingValue)")
                Text("↓ \(network?.download.formatted() ?? missingValue)")
            }
            .font(.caption.weight(.semibold))
        }
    }

    /// Largest combined rate in the history, with a floor so idle traffic stays near the baseline.
    private var peak: Double {
        max(history.map { $0.upload.bytesPerSecond + $0.download.bytesPerSecond }.max() ?? 0, 1_000)
    }
}

struct NetworkDetails: View {
    let network: NetworkSample?
    let history: History<NetworkSample>
    /// Display names, such as "Wi-Fi", keyed by BSD name.
    let interfaceNames: [String: String]

    @State private var hoverSlot: Int?

    var body: some View {
        // While hovering the chart, the legend shows the hovered sample instead of the latest one.
        let shown = hoverSlot.flatMap(history.element(inSlot:)) ?? network
        VStack(alignment: .leading, spacing: 6) {
            DetailsHeader(
                section: .network,
                value: "↓ \(network?.download.formatted() ?? missingValue)",
                summary: summary(
                    network.map { "↑ \($0.upload.formatted())" },
                    network.map { interface in interfaceNames[interface.interface].map { "\($0) (\(interface.interface))" } ?? interface.interface }
                )
            )
            RateChart(network: history, hoverSlot: $hoverSlot)
                .frame(height: 70)
                .padding(.vertical, 2)
            LegendRow(color: DashboardPalette.secondary, label: "Upload", value: shown?.upload.formatted() ?? missingValue)
            LegendRow(color: DashboardPalette.primary, label: "Download", value: shown?.download.formatted() ?? missingValue)
            if let peakUpload = history.map(\.upload).max(), let peakDownload = history.map(\.download).max() {
                DetailRow(label: "Peak", value: "↓ \(peakDownload.formatted()) · ↑ \(peakUpload.formatted())")
            }
            if let address = network?.address {
                DetailRow(label: "IP address", value: address)
            }
        }
    }
}
