import BarometryKit
import SwiftUI

struct DashboardView: View {
    let monitor: SystemMonitor

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
    }

    private var content: some View {
        VStack(spacing: 6) {
            if let battery = monitor.battery {
                BatterySection(battery: battery)
            }
            CPUSection(
                cpu: monitor.cpu,
                history: monitor.cpuHistory,
                frequency: monitor.frequencies?.cpu,
                temperature: monitor.sensors?.cpuTemperature
            )
            if let cpu = monitor.cpu {
                CoresSection(cpu: cpu)
            }
            if let gpu = monitor.gpu {
                GPUSection(
                    gpu: gpu,
                    temperature: monitor.sensors?.gpuTemperature,
                    frequency: monitor.frequencies?.gpu,
                    maximumFrequency: monitor.frequencies?.gpuMaximum,
                    totalMemory: monitor.memory?.total
                )
            }
            if let memory = monitor.memory {
                MemorySection(memory: memory)
            }
            if let sensors = monitor.sensors {
                SensorsSection(sensors: sensors, frequencies: monitor.frequencies)
            }
            NetworkSection(network: monitor.network, history: monitor.networkHistory)
            if let disk = monitor.disk {
                DiskSection(disk: disk)
            }
            HStack {
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
