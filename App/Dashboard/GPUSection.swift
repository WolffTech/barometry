import BarometryKit
import SwiftUI

struct GPUSection: View {
    let gpu: GPUSample
    let temperature: Temperature?
    let frequency: Frequency?
    let maximumFrequency: Frequency?
    let totalMemory: ByteCount?

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        DashboardCard {
            CardHeader(title: "GPU")
            HStack(spacing: 10) {
                GaugeRing(fraction: gpu.utilization.fraction, caption: "GPU", value: gpu.utilization.formatted())
                GaugeRing(fraction: memoryFraction, caption: "Mem", value: gpu.memoryInUse?.formattedCompact() ?? "—")
                GaugeRing(fraction: temperatureFraction(temperature), caption: "Temp", value: temperature?.formatted(in: temperatureUnit) ?? "—")
                GaugeRing(
                    fraction: frequencyFraction,
                    caption: "GHz",
                    value: frequency.map { $0.gigahertz.formatted(.number.precision(.fractionLength(1))) } ?? "—"
                )
            }
        }
    }

    private var memoryFraction: Double {
        guard let used = gpu.memoryInUse, let total = totalMemory else { return 0 }
        return Percent(Double(used.bytes), of: Double(total.bytes)).fraction
    }

    private var frequencyFraction: Double {
        guard let frequency, let maximumFrequency else { return 0 }
        return Percent(frequency.hertz, of: maximumFrequency.hertz).fraction
    }
}
