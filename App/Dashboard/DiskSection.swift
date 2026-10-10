import BarometryKit
import SwiftUI

struct DiskSection: View {
    let disk: DiskSample

    var body: some View {
        DashboardCard {
            HStack(spacing: 12) {
                Ring(fraction: disk.usage.fraction, color: DashboardPalette.primary, lineWidth: 4) {
                    Text(disk.usage.fraction * 100, format: .number.precision(.fractionLength(0)))
                        .font(.caption.weight(.medium).monospacedDigit())
                }
                .frame(width: 40, height: 40)
                .help("\(disk.usage.formatted()) used")
                VStack(alignment: .leading, spacing: 2) {
                    Text(disk.name)
                        .font(.callout.weight(.medium))
                    Text("\(disk.available.formatted(.file)) available")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
