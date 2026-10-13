import BarometryKit
import SwiftUI

/// System power, with battery, temperatures, and fans in the detail.
struct PowerSection: View {
    let sensors: SensorSample?
    let battery: BatterySample?
    let history: History<Power>
    @Binding var isExpanded: Bool

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        GlanceRow(
            title: "Power",
            summary: battery.map(\.chargeSummary) ?? summary(
                sensors?.cpuTemperature.map { "CPU \($0.formatted(in: temperatureUnit))" },
                sensors?.gpuTemperature.map { "GPU \($0.formatted(in: temperatureUnit))" }
            ),
            symbol: "bolt.fill",
            tint: .orange,
            isExpanded: $isExpanded
        ) {
            Sparkline(history, color: .orange, in: 0...peak) { $0.watts }
        } value: {
            Text(sensors?.systemPower?.formatted() ?? missingValue)
        } detail: {
            VStack(alignment: .leading, spacing: 6) {
                if let battery {
                    MeterRow(label: "Battery", value: battery.chargeSummary, fraction: battery.charge.fraction)
                        .padding(.bottom, 2)
                }
                if let temperature = sensors?.cpuTemperature {
                    DetailRow(label: "CPU temperature", value: temperature.formatted(in: temperatureUnit))
                }
                if let temperature = sensors?.gpuTemperature {
                    DetailRow(label: "GPU temperature", value: temperature.formatted(in: temperatureUnit))
                }
                ForEach(sensors?.fans ?? []) { fan in
                    DetailRow(
                        label: sensors?.fans.count == 1 ? "Fan" : "Fan \(fan.id + 1)",
                        value: fan.isSpinning ? "\(fan.rpm.formatted(.number.precision(.fractionLength(0)))) RPM" : "Off"
                    )
                }
            }
        }
    }

    /// Largest draw in the history, with a floor so idle draw doesn't fill the sparkline.
    private var peak: Double {
        max(history.map(\.watts).max() ?? 0, 10)
    }
}
