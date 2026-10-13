import BarometryKit
import SwiftUI

struct CPUSection: View {
    let cpu: CPUSample?
    let history: History<CPULoad>
    let frequencies: FrequencySample?
    let temperature: Temperature?
    @Binding var isExpanded: Bool

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        GlanceRow(
            title: "CPU",
            summary: summary(frequencies?.cpu?.formatted(), temperature?.formatted(in: temperatureUnit)),
            symbol: "cpu",
            tint: .blue,
            isExpanded: $isExpanded
        ) {
            Sparkline(history, color: .blue) { $0.total.fraction }
        } value: {
            Text(cpu?.total.total.formatted() ?? missingValue)
        } detail: {
            if let cpu {
                detail(cpu)
            }
        }
    }

    private func detail(_ cpu: CPUSample) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CoreBars(cores: cpu.cores)
            HStack(spacing: 16) {
                LegendRow(color: DashboardPalette.primary, label: "User", value: cpu.total.user.formatted())
                LegendRow(color: DashboardPalette.secondary, label: "System", value: cpu.total.system.formatted())
            }
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

/// One bar per core, user load stacked under system load, with a gap between core kinds.
private struct CoreBars: View {
    let cores: [CoreLoad]

    private static let height: CGFloat = 30

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(cores.enumerated()), id: \.element.id) { index, core in
                if index > 0, cores[index - 1].kind != core.kind {
                    Spacer()
                        .frame(width: 4)
                }
                bar(core)
            }
        }
        .frame(height: Self.height)
    }

    private func bar(_ core: CoreLoad) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(DashboardPalette.track)
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(DashboardPalette.secondary)
                        .frame(height: Self.height * core.load.system.fraction)
                    Rectangle()
                        .fill(DashboardPalette.primary)
                        .frame(height: Self.height * core.load.user.fraction)
                }
                .clipShape(.rect(cornerRadius: 2))
            }
            .frame(maxWidth: .infinity)
            .help("Core \(core.id) (\(core.kind.name)): \(core.load.total.formatted())")
            .accessibilityElement()
            .accessibilityLabel("Core \(core.id), \(core.kind.name)")
            .accessibilityValue(core.load.total.formatted())
    }
}

private extension CoreKind {
    var name: String {
        switch self {
        case .efficiency: "Efficiency"
        case .performance: "Performance"
        }
    }
}
