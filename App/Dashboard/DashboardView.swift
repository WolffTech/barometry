// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

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
    let keepAwake: KeepAwake
    let machine: Machine
    /// Display names, such as "Wi-Fi", keyed by BSD name.
    let interfaceNames: [String: String]
    let focus: DetailFocus
    let actions: Actions

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
        .environment(focus)
    }

    private func shows(_ section: DashboardSection) -> Bool {
        !preferences.hiddenDashboardSections.contains(section)
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            switch preferences.dashboardStyle {
            case .cluster:
                ClusterDashboard(monitor: monitor, interfaceNames: interfaceNames, shows: shows)
            case .glance:
                VStack(spacing: 2) {
                    rows
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
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
                temperature: monitor.sensors?.cpuTemperature
            )
        }
        if shows(.gpu), let gpu = monitor.gpu {
            GPUSection(
                gpu: gpu,
                history: monitor.gpuHistory,
                temperature: monitor.sensors?.gpuTemperature,
                frequency: monitor.frequencies?.gpu
            )
        }
        if shows(.memory), let memory = monitor.memory {
            MemorySection(memory: memory, history: monitor.memoryHistory)
        }
        if shows(.network) {
            NetworkSection(
                network: monitor.network,
                history: monitor.networkHistory,
                interfaceNames: interfaceNames
            )
        }
        if shows(.power), monitor.sensors != nil || monitor.battery != nil {
            PowerSection(
                sensors: monitor.sensors,
                battery: monitor.battery,
                history: monitor.powerHistory
            )
        }
        if shows(.disk), let disk = monitor.disk {
            DiskSection(disk: disk)
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Button("Activity Monitor", action: actions.openActivityMonitor)
            // Icon only: a label doesn't fit beside the other buttons.
            Toggle(isOn: Binding { keepAwake.isEnabled } set: { keepAwake.setEnabled($0) }) {
                Label("Keep Awake", systemImage: KeepAwake.systemImage)
            }
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .foregroundStyle(keepAwake.isEnabled ? AnyShapeStyle(DashboardSection.power.tint) : AnyShapeStyle(.secondary))
            .help(keepAwake.isEnabled ? "Keep Awake is on" : "Keep Awake")
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
