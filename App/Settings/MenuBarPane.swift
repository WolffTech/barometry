// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

struct MenuBarPane: View {
    @Bindable var preferences: Preferences
    let statusItems: StatusItemController
    @State private var draggedModule: MenuBarModule?

    var body: some View {
        Form {
            Section {
                MenuBarPreview(preferences: preferences, statusItems: statusItems)
            }
            Section("Layout") {
                ThumbnailPicker(
                    selection: $preferences.menuBarLayout,
                    options: [(.individual, "Individual"), (.combined, "Combined")]
                ) { layout in
                    MenuBarLayoutThumbnail(layout: layout)
                }
                Picker("Style", selection: $preferences.menuBarStyle) {
                    Text("Graphs").tag(MenuBarStyle.graphical)
                    Text("Text").tag(MenuBarStyle.text)
                }
                .pickerStyle(.segmented)
            }
            modules
        }
        .settingsPane()
    }

    private var modules: some View {
        let selection = preferences.menuBarModules
        // Order only applies to the combined item; individual items are ⌘-dragged.
        let isMovable = preferences.menuBarLayout == .combined
        return Section {
            ForEach(Array(selection.order.enumerated()), id: \.element) { index, module in
                Toggle(isOn: Binding {
                    selection.isVisible(module)
                } set: { isVisible in
                    preferences.menuBarModules.setVisible(isVisible, for: module)
                }) {
                    SettingsRowLabel(
                        title: module.name,
                        note: note(for: module, in: selection),
                        icon: IconTile(symbol: module.symbol, tint: module.tint, size: 22),
                        isMovable: isMovable
                    )
                }
                .toggleStyle(.switch)
                // The last module that's always shown stays so there's always an item to click.
                .disabled(!selection.isAvailable(module) || !selection.canHide(module))
                .reorderable(module, in: selection.order, dragging: $draggedModule, isEnabled: isMovable) { source, destination in
                    preferences.menuBarModules.move(fromOffsets: source, toOffset: destination)
                }
                .contextMenu {
                    if isMovable {
                        MoveCommands(index: index, count: selection.order.count) { source, destination in
                            preferences.menuBarModules.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                }
            }
        } header: {
            Text("Modules")
        } footer: {
            Group {
                switch preferences.menuBarLayout {
                case .individual: Text("Each module gets its own item. Hold ⌘ and drag items in the menu bar to rearrange them.")
                case .combined: Text("One item shows the modules in this order. Drag to rearrange them.")
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private func note(for module: MenuBarModule, in selection: MenuBarModuleSelection) -> String? {
        if !selection.isAvailable(module) {
            "Not available on this Mac"
        } else if module.showsOnlyWhileKeepingAwake {
            "Shown while Keep Awake is on"
        } else {
            nil
        }
    }
}
