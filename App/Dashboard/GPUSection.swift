import BarometryKit
import SwiftUI

struct GPUSection: View {
    let gpu: GPUSample
    let history: History<Percent>
    let temperature: Temperature?
    let frequency: Frequency?
    let maximumFrequency: Frequency?
    let totalMemory: ByteCount?
    @Binding var isExpanded: Bool

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        GlanceRow(
            title: "GPU",
            summary: summary(frequency?.formatted(), temperature?.formatted(in: temperatureUnit)),
            symbol: "cube.transparent",
            tint: .indigo,
            isExpanded: $isExpanded
        ) {
            Sparkline(history, color: .indigo) { $0.fraction }
        } value: {
            Text(gpu.utilization.formatted())
        } detail: {
            VStack(spacing: 8) {
                MeterRow(label: "Clock", value: clock, fraction: fraction(frequency?.hertz, of: maximumFrequency?.hertz))
                if let memory = gpu.memoryInUse {
                    MeterRow(
                        label: "Memory",
                        value: totalMemory.map { "\(memory.formattedCompact()) of \($0.formatted(.memory))" } ?? memory.formattedCompact(),
                        fraction: fraction(Double(memory.bytes), of: totalMemory.map { Double($0.bytes) })
                    )
                }
            }
        }
    }

    /// Nil frequency means the GPU was idle for the whole interval.
    private var clock: String {
        guard let frequency else { return "Idle" }
        guard let maximumFrequency else { return frequency.formatted() }
        return "\(frequency.formatted()) of \(maximumFrequency.formatted())"
    }

    private func fraction(_ part: Double?, of total: Double?) -> Double {
        guard let part, let total else { return 0 }
        return Percent(part, of: total).fraction
    }
}
