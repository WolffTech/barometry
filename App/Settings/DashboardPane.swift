// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

struct DashboardPane: View {
    @Bindable var preferences: Preferences
    @State private var draggedSection: DashboardSection?

    var body: some View {
        Form {
            Section("Style") {
                ThumbnailPicker(
                    selection: $preferences.dashboardStyle,
                    options: [(.cluster, "Instrument Cluster"), (.glance, "Glance")]
                ) { style in
                    DashboardStyleThumbnail(style: style)
                }
            }
            sections
        }
        .settingsPane()
    }

    private var sections: some View {
        let order = preferences.dashboardSectionOrder
        return Section {
            ForEach(Array(order.enumerated()), id: \.element) { index, section in
                Toggle(isOn: isShown(section)) {
                    SettingsRowLabel(
                        title: section.name,
                        note: section == .power ? "Battery, temperatures, and fans" : nil,
                        icon: IconTile(section: section, size: 22),
                        isMovable: true
                    )
                }
                .toggleStyle(.switch)
                .reorderable(section, in: order, dragging: $draggedSection, move: preferences.moveDashboardSections)
                .contextMenu {
                    MoveCommands(index: index, count: order.count, move: preferences.moveDashboardSections)
                }
            }
        } header: {
            Text("Sections")
        } footer: {
            Group {
                switch preferences.dashboardStyle {
                case .cluster: Text("Drag to rearrange. Dials and rings each follow this order, with network between them.")
                case .glance: Text("Drag to rearrange.")
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private func isShown(_ section: DashboardSection) -> Binding<Bool> {
        Binding {
            !preferences.hiddenDashboardSections.contains(section)
        } set: { isShown in
            if isShown {
                preferences.hiddenDashboardSections.remove(section)
            } else {
                preferences.hiddenDashboardSections.insert(section)
            }
        }
    }
}
