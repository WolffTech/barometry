import BarometryKit
import SwiftUI

struct DashboardView: View {
    let monitor: SystemMonitor

    var body: some View {
        VStack(spacing: 8) {
            if let battery = monitor.battery {
                BatterySection(battery: battery)
            }
            CPUSection(cpu: monitor.cpu, history: monitor.cpuHistory)
            if let cpu = monitor.cpu {
                CoresSection(cpu: cpu)
            }
            if let memory = monitor.memory {
                MemorySection(memory: memory)
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
            .padding(.top, 2)
        }
        .padding(10)
        .frame(width: 300)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }
}
