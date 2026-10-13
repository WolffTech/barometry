import BarometryKit
import SwiftUI

struct MemorySection: View {
    let memory: MemorySample
    let history: History<Percent>
    @Binding var isExpanded: Bool

    var body: some View {
        GlanceRow(
            title: "Memory",
            summary: summary(
                "\(memory.used.formatted(.memory)) of \(memory.total.formatted(.memory))",
                memory.pressure.level == .normal ? nil : "\(memory.pressure.level.name) pressure"
            ),
            symbol: "memorychip",
            tint: .pink,
            isExpanded: $isExpanded
        ) {
            Sparkline(history, color: .pink) { $0.fraction }
        } value: {
            Text(memory.usage.formatted())
        } detail: {
            VStack(alignment: .leading, spacing: 6) {
                SegmentedBar(segments: [
                    (share(memory.app), DashboardPalette.primary),
                    (share(memory.wired), DashboardPalette.secondary),
                    (share(memory.compressed), DashboardPalette.tertiary),
                ])
                .padding(.bottom, 2)
                LegendRow(color: DashboardPalette.primary, label: "App", value: memory.app.formatted(.memory))
                LegendRow(color: DashboardPalette.secondary, label: "Wired", value: memory.wired.formatted(.memory))
                LegendRow(color: DashboardPalette.tertiary, label: "Compressed", value: memory.compressed.formatted(.memory))
                DetailRow(label: "Cached files", value: memory.cached.formatted(.memory))
                DetailRow(label: "Pressure", value: "\(memory.pressure.percent.formatted()) · \(memory.pressure.level.name)")
            }
        }
    }

    private func share(_ bytes: ByteCount) -> Double {
        Percent(Double(bytes.bytes), of: Double(memory.total.bytes)).fraction
    }
}
