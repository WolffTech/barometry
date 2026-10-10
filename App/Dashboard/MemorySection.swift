import BarometryKit
import SwiftUI

struct MemorySection: View {
    let memory: MemorySample

    var body: some View {
        DashboardCard {
            CardHeader(title: "Memory", detail: "\(memory.used.formatted(.memory)) of \(memory.total.formatted(.memory))")
            HStack(spacing: 24) {
                Ring(fraction: memory.pressure.percent.fraction, color: pressureColor, lineWidth: 8) {
                    ringLabel(memory.pressure.percent.formatted(), caption: pressureCaption)
                }
                SegmentedRing(segments: segments, lineWidth: 8) {
                    ringLabel(memory.usage.formatted(), caption: "Used")
                }
            }
            .frame(height: 104)
            .frame(maxWidth: .infinity)
            VStack(spacing: 4) {
                LegendRow(color: DashboardPalette.primary, label: "App", value: memory.app.formatted(.memory))
                LegendRow(color: DashboardPalette.secondary, label: "Wired", value: memory.wired.formatted(.memory))
                LegendRow(color: DashboardPalette.tertiary, label: "Compressed", value: memory.compressed.formatted(.memory))
            }
        }
    }

    private var segments: [(fraction: Double, color: Color)] {
        let total = Double(memory.total.bytes)
        return [
            (Percent(Double(memory.app.bytes), of: total).fraction, DashboardPalette.primary),
            (Percent(Double(memory.wired.bytes), of: total).fraction, DashboardPalette.secondary),
            (Percent(Double(memory.compressed.bytes), of: total).fraction, DashboardPalette.tertiary),
        ]
    }

    /// Status colors are reserved for elevated pressure and always paired with the level's name.
    private var pressureColor: Color {
        switch memory.pressure.level {
        case .normal: DashboardPalette.primary
        case .warning: .orange
        case .critical: .red
        }
    }

    private var pressureCaption: String {
        switch memory.pressure.level {
        case .normal: "Pressure"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }

    private func ringLabel(_ value: String, caption: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.title2.weight(.medium).monospacedDigit())
            Text(caption.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
