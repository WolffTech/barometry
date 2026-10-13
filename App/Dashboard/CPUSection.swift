import BarometryKit
import Charts
import SwiftUI

struct CPUSection: View {
    let cpu: CPUSample?
    let history: History<CPULoad>
    let frequencies: FrequencySample?
    let temperature: Temperature?

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        GlanceRow(section: .cpu, summary: summary(frequencies?.cpu?.formatted(), temperature?.formatted(in: temperatureUnit))) {
            Sparkline(history, color: DashboardSection.cpu.tint) { $0.total.fraction }
        } value: {
            Text(cpu?.total.total.formatted() ?? missingValue)
        }
    }
}

struct CPUDetails: View {
    let cpu: CPUSample
    let history: History<CPULoad>
    let frequencies: FrequencySample?
    let temperature: Temperature?

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailsHeader(
                section: .cpu,
                value: cpu.total.total.formatted(),
                summary: summary(frequencies?.cpu?.formatted(), temperature?.formatted(in: temperatureUnit))
            )
            LoadChart(history: history)
                .frame(height: 64)
            HStack(spacing: 16) {
                LegendRow(color: DashboardPalette.primary, label: "User", value: cpu.total.user.formatted())
                LegendRow(color: DashboardPalette.secondary, label: "System", value: cpu.total.system.formatted())
            }
            DetailsHeading("Cores")
            CoreGrid(cores: cpu.cores)
            ForEach([CoreKind.efficiency, .performance], id: \.self) { kind in
                if let average = cpu.averageLoad(of: kind) {
                    let count = cpu.cores.count { $0.kind == kind }
                    DetailRow(
                        label: "\(kind.name) · \(count)",
                        value: summary(average.formatted(), frequency(of: kind)?.formatted()) ?? missingValue
                    )
                }
            }
        }
    }

    private func frequency(of kind: CoreKind) -> Frequency? {
        kind == .efficiency ? frequencies?.efficiencyCores : frequencies?.performanceCores
    }
}

/// Total load over the whole history, user stacked under system.
private struct LoadChart: View {
    let history: History<CPULoad>

    var body: some View {
        Chart {
            ForEach(history.slotted, id: \.slot) { slot, load in
                BarMark(x: .value("Time", slot), y: .value("Load", load.user.fraction), width: .fixed(1.5))
                    .foregroundStyle(by: .value("Kind", "User"))
                BarMark(x: .value("Time", slot), y: .value("Load", load.system.fraction), width: .fixed(1.5))
                    .foregroundStyle(by: .value("Kind", "System"))
            }
        }
        .chartForegroundStyleScale(["User": DashboardPalette.primary, "System": DashboardPalette.secondary])
        .chartXScale(domain: history.slotDomain)
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: [0.25, 0.5, 0.75]) {
                AxisGridLine()
            }
        }
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }
}

/// One cell per core, shaded by load, with efficiency cores first.
private struct CoreGrid: View {
    let cores: [CoreLoad]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(cores.enumerated()), id: \.element.id) { index, core in
                cell(core, number: cores[..<index].count { $0.kind == core.kind } + 1)
            }
        }
    }

    private func cell(_ core: CoreLoad, number: Int) -> some View {
        let load = core.load.total
        return VStack(spacing: 0) {
            Text("\(core.kind.abbreviation)\(number)")
                .font(.system(size: 9))
                .opacity(0.75)
            Text(load.formatted())
                .font(.caption2)
                .monospacedDigit()
        }
        .foregroundStyle(load.fraction > 0.4 ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(DashboardSection.cpu.tint.opacity(0.15 + load.fraction * 0.85), in: .rect(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Core \(core.id), \(core.kind.name)")
        .accessibilityValue(load.formatted())
    }
}

private extension CoreKind {
    var name: String {
        switch self {
        case .efficiency: "Efficiency"
        case .performance: "Performance"
        }
    }

    var abbreviation: String {
        switch self {
        case .efficiency: "E"
        case .performance: "P"
        }
    }
}
