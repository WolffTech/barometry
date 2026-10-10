import BarometryKit
import SwiftUI

struct SensorsSection: View {
    let sensors: SensorSample
    let frequencies: FrequencySample?

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        DashboardCard {
            CardHeader(title: "Sensors", detail: sensors.systemPower.map { "\($0.formatted()) system power" })
            HStack(spacing: 10) {
                GaugeRing(
                    fraction: temperatureFraction(sensors.cpuTemperature),
                    caption: "CPU",
                    value: sensors.cpuTemperature?.formatted(in: temperatureUnit) ?? "—",
                    detail: frequencies?.cpu?.formatted()
                )
                GaugeRing(
                    fraction: temperatureFraction(sensors.gpuTemperature),
                    caption: "GPU",
                    value: sensors.gpuTemperature?.formatted(in: temperatureUnit) ?? "—",
                    detail: frequencies?.gpu?.formatted()
                )
                fanGauge
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
        }
    }

    /// Shows the fastest fan; every fan's speed is in the tooltip.
    @ViewBuilder private var fanGauge: some View {
        let fastest = sensors.fans.max { $0.rpm < $1.rpm }
        GaugeRing(
            fraction: fastest.flatMap { fan in fan.maximumRPM.map { fan.rpm / $0 } } ?? 0,
            caption: "Fans",
            value: fastest.map { $0.isSpinning ? $0.rpm.formatted(.number.precision(.fractionLength(0))) : "Off" } ?? "—",
            detail: fastest?.isSpinning == true ? "RPM" : nil
        )
        .help(sensors.fans.map { "Fan \($0.id + 1): \(Int($0.rpm)) RPM" }.joined(separator: "\n"))
    }
}
