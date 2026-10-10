import BarometryKit
import SwiftUI

struct DashboardView: View {
    let monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Barometry")
                .font(.headline)
            // Plain readout to check live values. The styled sections replace it in the dashboard milestone.
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                row("CPU", cpu)
                row("Cores", cores)
                row("Memory", memory)
                row("Pressure", pressure)
                row("Network", network)
                row("Disk", disk)
                row("Battery", battery)
            }
            .font(.callout.monospacedDigit())
            Divider()
            HStack {
                Spacer()
                Button("Quit Barometry") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }

    private func row(_ label: String, _ value: String?) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value ?? "—")
        }
    }

    private var cpu: String? {
        monitor.cpu.map { cpu in
            "\(cpu.total.total.formatted()) · user \(cpu.total.user.formatted()), system \(cpu.total.system.formatted())"
        }
    }

    private var cores: String? {
        monitor.cpu.map { cpu in
            let efficiency = cpu.averageLoad(of: .efficiency)?.formatted() ?? "—"
            let performance = cpu.averageLoad(of: .performance)?.formatted() ?? "—"
            return "E \(efficiency) · P \(performance) · \(cpu.cores.count) cores"
        }
    }

    private var memory: String? {
        monitor.memory.map { memory in
            "\(memory.usage.formatted()) · \(memory.used.formatted(.memory)) of \(memory.total.formatted(.memory))"
        }
    }

    private var pressure: String? {
        monitor.memory.map { memory in
            "\(memory.pressure.percent.formatted()) · \(memory.pressure.level)"
        }
    }

    private var network: String? {
        monitor.network.map { network in
            "↑ \(network.upload.formatted())  ↓ \(network.download.formatted()) · \(network.interface)"
        }
    }

    private var disk: String? {
        monitor.disk.map { disk in
            "\(disk.available.formatted(.file)) available · \(disk.usage.formatted()) used"
        }
    }

    private var battery: String? {
        monitor.battery.map { battery in
            let state = switch battery.state {
            case .charging(let timeToFull):
                "Charging" + (timeToFull.map { ", full in \($0.formatted(.time(pattern: .hourMinute)))" } ?? "")
            case .charged:
                "Charged"
            case .notCharging:
                "Not charging"
            case .discharging(let timeRemaining):
                timeRemaining.map { "\($0.formatted(.time(pattern: .hourMinute))) remaining" } ?? "On battery"
            }
            return "\(battery.charge.formatted()) · \(state)"
        }
    }
}
