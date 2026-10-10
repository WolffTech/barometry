import BarometryKit
import Charts
import SwiftUI

struct CPUSection: View {
    let cpu: CPUSample?
    let history: History<CPULoad>
    let frequency: Frequency?
    let temperature: Temperature?

    @State private var hoverSlot: Int?

    var body: some View {
        // While hovering, the legend shows the hovered sample instead of the latest one.
        let shown = hoverSlot.flatMap(history.element(inSlot:)) ?? cpu?.total
        DashboardCard {
            CardHeader(title: "CPU", detail: detail(load: shown))
            chart
            HStack(spacing: 16) {
                LegendRow(color: DashboardPalette.primary, label: "User", value: shown?.user.formatted() ?? "—")
                LegendRow(color: DashboardPalette.secondary, label: "System", value: shown?.system.formatted() ?? "—")
            }
        }
    }

    private func detail(load: CPULoad?) -> String {
        [load?.total.formatted(), frequency?.formatted(), temperature?.formatted()]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    private var chart: some View {
        Chart {
            ForEach(history.slotted, id: \.slot) { slot, load in
                BarMark(x: .value("Time", slot), y: .value("Load", load.user.fraction), width: .fixed(1.5))
                    .foregroundStyle(by: .value("Kind", "User"))
                BarMark(x: .value("Time", slot), y: .value("Load", load.system.fraction), width: .fixed(1.5))
                    .foregroundStyle(by: .value("Kind", "System"))
            }
            if let hoverSlot, history.element(inSlot: hoverSlot) != nil {
                RuleMark(x: .value("Time", hoverSlot))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartForegroundStyleScale(["User": DashboardPalette.primary, "System": DashboardPalette.secondary])
        .chartXScale(domain: history.slotDomain)
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartHoverSlot($hoverSlot)
        .frame(height: 48)
    }
}
