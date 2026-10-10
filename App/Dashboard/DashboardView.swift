import BarometryKit
import SwiftUI

struct DashboardView: View {
    let monitor: SystemMonitor
    let preferences: Preferences
    let openSettings: () -> Void

    var body: some View {
        // Shows everything when it fits; otherwise the panel caps its height and this scrolls.
        ViewThatFits(in: .vertical) {
            content
            ScrollView {
                content
            }
            .scrollIndicators(.automatic)
        }
        .frame(width: 300)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .environment(\.temperatureUnit, preferences.temperatureUnit)
    }

    private func shows(_ section: DashboardSection) -> Bool {
        !preferences.hiddenDashboardSections.contains(section)
    }

    private var content: some View {
        VStack(spacing: 6) {
            if shows(.battery), let battery = monitor.battery {
                BatterySection(battery: battery)
            }
            if shows(.cpu) {
                CPUSection(
                    cpu: monitor.cpu,
                    history: monitor.cpuHistory,
                    frequency: monitor.frequencies?.cpu,
                    temperature: monitor.sensors?.cpuTemperature
                )
            }
            if shows(.cores), let cpu = monitor.cpu {
                CoresSection(cpu: cpu)
            }
            if shows(.gpu), let gpu = monitor.gpu {
                GPUSection(
                    gpu: gpu,
                    temperature: monitor.sensors?.gpuTemperature,
                    frequency: monitor.frequencies?.gpu,
                    maximumFrequency: monitor.frequencies?.gpuMaximum,
                    totalMemory: monitor.memory?.total
                )
            }
            if shows(.memory), let memory = monitor.memory {
                MemorySection(memory: memory)
            }
            if shows(.sensors), let sensors = monitor.sensors {
                SensorsSection(sensors: sensors, frequencies: monitor.frequencies)
            }
            if shows(.network) {
                NetworkSection(network: monitor.network, history: monitor.networkHistory)
            }
            if shows(.disk), let disk = monitor.disk {
                DiskSection(disk: disk)
            }
            HStack {
                Button("Settings…", action: openSettings)
                    .keyboardShortcut(",")
                Spacer()
                Button("Quit Barometry") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(10)
    }
}
