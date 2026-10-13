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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DetailsHeader(
                section: .disk,
                value: disk.available.formatted(.file),
                summary: "available on \(disk.name)"
            )
            MeterRow(
                label: "Used",
                value: "\(ByteCount(bytes: disk.total.bytes - disk.available.bytes).formatted(.file)) of \(disk.total.formatted(.file))",
                fraction: disk.usage.fraction
            )
            .padding(.top, 4)
        }
    }
}
