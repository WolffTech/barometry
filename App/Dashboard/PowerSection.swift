// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

/// System power, with battery, temperatures, and fans in the details.
struct PowerSection: View {
    let sensors: SensorSample?
    let battery: BatterySample?
    let history: History<Power>

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        GlanceRow(
            section: .power,
            summary: battery.map(\.chargeSummary) ?? summary(
                sensors?.cpuTemperature.map { "CPU \($0.formatted(in: temperatureUnit))" },
                sensors?.gpuTemperature.map { "GPU \($0.formatted(in: temperatureUnit))" }
            )
        ) {
            Sparkline(history, color: DashboardSection.power.tint, in: 0...powerPeak(history)) { $0.watts }
        } value: {
            Text(sensors?.systemPower?.formatted() ?? missingValue)
        }
    }
}

struct PowerDetails: View {
    let sensors: SensorSample?
    let battery: BatterySample?
    let history: History<Power>
    let processes: TopProcesses?
    let isKeepingAwake: Bool

    @Environment(\.temperatureUnit) private var temperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DetailsHeader(
                section: .power,
                value: sensors?.systemPower?.formatted() ?? missingValue,
                summary: "System power"
            )
            Sparkline(history, color: DashboardSection.power.tint, in: 0...powerPeak(history), window: history.capacity, showsGrid: true) { $0.watts }
                .frame(height: 56)
                .accessibilityHidden(true)
                .padding(.bottom, 2)
            if let battery {
                MeterRow(label: "Battery", value: battery.chargeSummary, fraction: battery.charge.fraction, color: .green)
                    .padding(.bottom, 2)
                if let health = battery.health {
                    DetailRow(label: "Maximum capacity", value: health.maximumCapacity.formatted())
                    DetailRow(label: "Cycle count", value: health.cycleCount.formatted())
                }
            }
            if isKeepingAwake {
                DetailRow(label: "Keep awake", value: "On")
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
            ProcessList(
                title: "Top energy use",
                processes: processes?.byPower,
                tint: DashboardSection.power.tint,
                measure: \.power.watts,
                value: \.power.processFormatted
            )
            .padding(.top, 4)
        }
    }
}

/// Largest draw in the history, with a floor so idle draw doesn't fill the chart.
func powerPeak(_ history: History<Power>) -> Double {
    max(history.map(\.watts).max() ?? 0, 10)
}
