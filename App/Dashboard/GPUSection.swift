// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

struct GPUSection: View {
    let gpu: GPUSample
    let history: History<Percent>
    let temperature: Temperature?
    let frequency: Frequency?

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        GlanceRow(section: .gpu, summary: summary(frequency?.formatted(), temperature?.formatted(in: temperatureUnit))) {
            Sparkline(history, color: DashboardSection.gpu.tint) { $0.fraction }
        } value: {
            Text(gpu.utilization.formatted())
        }
    }
}

struct GPUDetails: View {
    let gpu: GPUSample
    let history: History<Percent>
    let temperature: Temperature?
    let frequency: Frequency?
    let maximumFrequency: Frequency?
    let totalMemory: ByteCount?
    let processes: TopProcesses?

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailsHeader(
                section: .gpu,
                value: gpu.utilization.formatted(),
                summary: summary(frequency?.formatted() ?? "Idle", temperature?.formatted(in: temperatureUnit))
            )
            Sparkline(history, color: DashboardSection.gpu.tint, window: history.capacity, showsGrid: true) { $0.fraction }
                .frame(height: 64)
                .accessibilityHidden(true)
            MeterRow(label: "Clock", value: clock, fraction: fraction(frequency?.hertz, of: maximumFrequency?.hertz))
            if let memory = gpu.memoryInUse {
                MeterRow(
                    label: "Memory",
                    value: totalMemory.map { "\(memory.formattedCompact()) of \($0.formatted(.memory))" } ?? memory.formattedCompact(),
                    fraction: fraction(Double(memory.bytes), of: totalMemory.map { Double($0.bytes) })
                )
            }
            // macOS doesn't expose GPU time per process without root, so this shows CPU use instead.
            ProcessList.byCPU(processes, title: "Top processes by CPU", tint: DashboardSection.gpu.tint)
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
