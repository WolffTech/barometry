// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

struct MemorySection: View {
    let memory: MemorySample
    let history: History<Percent>

    var body: some View {
        GlanceRow(
            section: .memory,
            summary: summary(
                "\(memory.used.formatted(.memory)) of \(memory.total.formatted(.memory))",
                memory.pressure.level == .normal ? nil : "\(memory.pressure.level.name) pressure"
            )
        ) {
            Sparkline(history, color: memory.pressure.level.tint) { $0.fraction }
        } value: {
            Text(memory.pressure.percent.formatted())
                .foregroundStyle(memory.pressure.level.valueStyle)
        }
    }
}

struct MemoryDetails: View {
    let memory: MemorySample
    let history: History<Percent>
    let processes: TopApps?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DetailsHeader(
                section: .memory,
                value: memory.pressure.percent.formatted(),
                summary: "\(memory.pressure.level.name) pressure"
            )
            Sparkline(history, color: memory.pressure.level.tint, window: history.capacity, showsGrid: true) { $0.fraction }
                .frame(height: 64)
                .accessibilityHidden(true)
                .padding(.bottom, 2)
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
            DetailRow(label: "Memory used", value: "\(memory.used.formatted(.memory)) of \(memory.total.formatted(.memory))")
            if let swap = memory.swapUsed {
                DetailRow(label: "Swap used", value: swap.bytes == 0 ? "None" : swap.formatted(.memory))
            }
            AppList(
                title: "Top apps",
                apps: processes?.byMemory,
                tint: DashboardSection.memory.tint,
                measure: { Double($0.memory.bytes) },
                value: { $0.memory.formattedCompact() }
            )
            .padding(.top, 4)
        }
    }

    private func share(_ bytes: ByteCount) -> Double {
        Percent(Double(bytes.bytes), of: Double(memory.total.bytes)).fraction
    }
}
