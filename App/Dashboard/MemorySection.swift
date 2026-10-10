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
            .frame(height: 76)
            .frame(maxWidth: .infinity)
            HStack(alignment: .top, spacing: 4) {
                legendColumn(DashboardPalette.primary, "App", memory.app)
                legendColumn(DashboardPalette.secondary, "Wired", memory.wired)
                legendColumn(DashboardPalette.tertiary, "Compressed", memory.compressed)
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

    private func legendColumn(_ color: Color, _ label: String, _ bytes: ByteCount) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Text(bytes.formatted(.memory))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.leading, 13)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
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
