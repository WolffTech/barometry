import BarometryKit
import SwiftUI

struct CoresSection: View {
    let cpu: CPUSample

    var body: some View {
        DashboardCard {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(rows, id: \.first?.id) { row in
                    GridRow {
                        ForEach(row) { core in
                            Ring(fraction: core.load.total.fraction, color: color(for: core.kind))
                                .help("Core \(core.id) (\(name(for: core.kind))): \(core.load.total.formatted())")
                        }
                    }
                }
            }
            HStack(spacing: 16) {
                ForEach([CoreKind.efficiency, .performance], id: \.self) { kind in
                    if let average = cpu.averageLoad(of: kind) {
                        LegendRow(color: color(for: kind), label: name(for: kind), value: average.formatted())
                    }
                }
            }
        }
    }

    /// At most eight rings per row, split evenly so 12 cores become two rows of six.
    private var rows: [[CoreLoad]] {
        let cores = cpu.cores
        let rowCount = (cores.count + 7) / 8
        let perRow = max((cores.count + rowCount - 1) / max(rowCount, 1), 1)
        return stride(from: 0, to: cores.count, by: perRow).map { Array(cores[$0..<min($0 + perRow, cores.count)]) }
    }

    private func color(for kind: CoreKind) -> Color {
        kind == .efficiency ? DashboardPalette.secondary : DashboardPalette.primary
    }

    private func name(for kind: CoreKind) -> String {
        kind == .efficiency ? "Efficiency" : "Performance"
    }
}
