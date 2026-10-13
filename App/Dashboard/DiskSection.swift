import BarometryKit
import SwiftUI

struct DiskSection: View {
    let disk: DiskSample

    var body: some View {
        GlanceRow(
            title: disk.name,
            summary: "\(disk.available.formatted(.file)) available",
            symbol: "internaldrive",
            tint: .gray
        ) {
            ProgressBar(fraction: disk.usage.fraction)
        } value: {
            Text(disk.usage.formatted())
        }
    }
}
