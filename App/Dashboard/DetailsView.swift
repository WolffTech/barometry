// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

/// The focused section's details, shown in a panel beside the dashboard.
struct DetailsView: View {
    /// What the panel needs to place itself.
    struct Layout: Equatable {
        let target: DetailFocus.Target?
        let contentHeight: CGFloat
    }

    static let width: CGFloat = 300

    /// Sections whose details list top processes, which the monitor reads only while they're shown.
    static func listsProcesses(_ section: DashboardSection) -> Bool {
        switch section {
        case .cpu, .gpu, .memory, .power: true
        case .network, .disk: false
        }
    }

    let monitor: SystemMonitor
    let preferences: Preferences
    let keepAwake: KeepAwake
    /// Display names, such as "Wi-Fi", keyed by BSD name.
    let interfaceNames: [String: String]
    let focus: DetailFocus
    let layoutChanged: (Layout) -> Void

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        // Scrolls only when the panel is capped to the screen height.
        ScrollView {
            if let section = focus.shown?.section {
                details(section)
                    .padding(14)
                    .frame(width: Self.width, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .onHover { focus.pointerOverDetails($0) }
        .environment(\.temperatureUnit, preferences.temperatureUnit)
        .onChange(of: Layout(target: focus.shown, contentHeight: contentHeight), initial: true) { _, layout in
            layoutChanged(layout)
        }
    }

    @ViewBuilder private func details(_ section: DashboardSection) -> some View {
        switch section {
        case .cpu:
            if let cpu = monitor.cpu {
                CPUDetails(
                    cpu: cpu,
                    history: monitor.cpuHistory,
                    frequencies: monitor.frequencies,
                    temperature: monitor.sensors?.cpuTemperature,
                    processes: monitor.processes
                )
            }
        case .gpu:
            if let gpu = monitor.gpu {
                GPUDetails(
                    gpu: gpu,
                    history: monitor.gpuHistory,
                    temperature: monitor.sensors?.gpuTemperature,
                    frequency: monitor.frequencies?.gpu,
                    maximumFrequency: monitor.frequencies?.gpuMaximum,
                    totalMemory: monitor.memory?.total,
                    processes: monitor.processes
                )
            }
        case .memory:
            if let memory = monitor.memory {
                MemoryDetails(memory: memory, history: monitor.memoryHistory, processes: monitor.processes)
            }
        case .network:
            NetworkDetails(network: monitor.network, history: monitor.networkHistory, interfaceNames: interfaceNames)
        case .power:
            PowerDetails(
                sensors: monitor.sensors,
                battery: monitor.battery,
                history: monitor.powerHistory,
                processes: monitor.processes,
                isKeepingAwake: keepAwake.isEnabled
            )
        case .disk:
            if let disk = monitor.disk {
                DiskDetails(
                    disk: disk,
                    activity: monitor.diskActivity,
                    history: monitor.diskActivityHistory,
                    otherVolumes: monitor.otherVolumes
                )
            }
        }
    }
}
