import BarometryKit
import SwiftUI

struct DashboardView: View {
    struct Actions {
        let openActivityMonitor: () -> Void
        let openSettings: () -> Void
        /// Called with the content's full height whenever it changes, so the panel can fit it.
        let contentHeightChanged: (CGFloat) -> Void
    }

    let monitor: SystemMonitor
    let preferences: Preferences
    let machine: Machine
    /// Display names, such as "Wi-Fi", keyed by BSD name.
    let interfaceNames: [String: String]
    let actions: Actions

    /// At most one row is expanded at a time.
    @State private var expanded: DashboardSection?

    init(
        monitor: SystemMonitor,
        preferences: Preferences,
        machine: Machine,
        interfaceNames: [String: String],
        expanded: DashboardSection?,
        actions: Actions
    ) {
        self.monitor = monitor
        self.preferences = preferences
        self.machine = machine
        self.interfaceNames = interfaceNames
        self.actions = actions
        _expanded = State(initialValue: expanded)
    }

    var body: some View {
        // Scrolls only when the panel is capped to the screen height.
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    actions.contentHeightChanged(height)
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 320)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .environment(\.temperatureUnit, preferences.temperatureUnit)
    }

    private func shows(_ section: DashboardSection) -> Bool {
        !preferences.hiddenDashboardSections.contains(section)
    }

    private func isExpanded(_ section: DashboardSection) -> Binding<Bool> {
        Binding {
            expanded == section
        } set: { isExpanded in
            expanded = isExpanded ? section : nil
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 2) {
                rows
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            Divider()
            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(machine.name ?? "This Mac")
                .font(.headline)
            if let specs = summary(
                machine.chip,
                monitor.cpu.map { "\($0.cores.count) cores" },
                monitor.memory?.total.formatted(.memory)
            ) {
                Text(specs)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var rows: some View {
        if shows(.cpu) {
            CPUSection(
                cpu: monitor.cpu,
                history: monitor.cpuHistory,
                frequencies: monitor.frequencies,
                temperature: monitor.sensors?.cpuTemperature,
                isExpanded: isExpanded(.cpu)
            )
        }
        if shows(.gpu), let gpu = monitor.gpu {
            GPUSection(
                gpu: gpu,
                history: monitor.gpuHistory,
                temperature: monitor.sensors?.gpuTemperature,
                frequency: monitor.frequencies?.gpu,
                maximumFrequency: monitor.frequencies?.gpuMaximum,
                totalMemory: monitor.memory?.total,
                isExpanded: isExpanded(.gpu)
            )
        }
        if shows(.memory), let memory = monitor.memory {
            MemorySection(memory: memory, history: monitor.memoryHistory, isExpanded: isExpanded(.memory))
        }
        if shows(.network) {
            NetworkSection(
                network: monitor.network,
                history: monitor.networkHistory,
                interfaceNames: interfaceNames,
                isExpanded: isExpanded(.network)
            )
        }
        if shows(.power), monitor.sensors != nil || monitor.battery != nil {
            PowerSection(
                sensors: monitor.sensors,
                battery: monitor.battery,
                history: monitor.powerHistory,
                isExpanded: isExpanded(.power)
            )
        }
        if shows(.disk), let disk = monitor.disk {
            DiskSection(disk: disk)
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Button("Activity Monitor", action: actions.openActivityMonitor)
            Spacer()
            Button("Settings…", action: actions.openSettings)
                .keyboardShortcut(",")
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.accessoryBar)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
