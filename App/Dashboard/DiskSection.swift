import BarometryKit
import SwiftUI

struct DiskSection: View {
    let disk: DiskSample

    var body: some View {
        GlanceRow(section: .disk, title: disk.name, summary: "\(disk.available.formatted(.file)) available") {
            ProgressBar(fraction: disk.usage.fraction)
        } value: {
            Text(disk.usage.formatted())
        }
    }
}

struct DiskDetails: View {
    let disk: DiskSample
    let activity: DiskActivity?
    let history: History<DiskActivity>
    /// Mounted local volumes other than the startup disk.
    let otherVolumes: [DiskSample]

    @State private var hoverSlot: Int?

    var body: some View {
        // While hovering the chart, the legend shows the hovered sample instead of the latest one.
        let shown = hoverSlot.flatMap(history.element(inSlot:)) ?? activity
        VStack(alignment: .leading, spacing: 6) {
            DetailsHeader(
                section: .disk,
                value: disk.available.formatted(.file),
                summary: "available on \(disk.name)"
            )
            volume(disk, label: "Used")
                .padding(.top, 4)
            DetailsHeading("Activity")
            RateChart(history: history, upper: \.write, lower: \.read, hoverSlot: $hoverSlot)
                .frame(height: 56)
                .padding(.vertical, 2)
            LegendRow(color: DashboardPalette.secondary, label: "Write", value: shown?.write.formatted() ?? missingValue)
            LegendRow(color: DashboardPalette.primary, label: "Read", value: shown?.read.formatted() ?? missingValue)
            if !otherVolumes.isEmpty {
                DetailsHeading("Other volumes")
                ForEach(Array(otherVolumes.enumerated()), id: \.offset) { _, volume in
                    self.volume(volume, label: volume.name)
                }
            }
        }
    }

    private func volume(_ volume: DiskSample, label: String) -> some View {
        MeterRow(
            label: label,
            value: "\(ByteCount(bytes: volume.total.bytes - volume.available.bytes).formatted(.file)) of \(volume.total.formatted(.file))",
            fraction: volume.usage.fraction
        )
    }
}
