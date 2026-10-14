// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import BarometryKit
import SwiftUI

/// A classic settings window: toolbar tabs, each pane sized to its content.
final class SettingsWindowController {
    private let preferences: Preferences
    private let updates: UpdateController
    private let statusItems: StatusItemController
    private var window: NSWindow?

    init(preferences: Preferences, updates: UpdateController, statusItems: StatusItemController) {
        self.preferences = preferences
        self.updates = updates
        self.statusItems = statusItems
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // Barometry has no Dock icon, so bring it forward or the window opens behind others.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        for item in [
            tab("General", symbol: "gearshape", GeneralPane(preferences: preferences)),
            tab("Menu Bar", symbol: "menubar.rectangle", MenuBarPane(preferences: preferences, statusItems: statusItems)),
            tab("Dashboard", symbol: "gauge.with.dots.needle.67percent", DashboardPane(preferences: preferences)),
            tab("Keep Awake", symbol: KeepAwake.systemImage, KeepAwakePane(preferences: preferences)),
            tab("Updates", symbol: "arrow.down.circle", UpdatesPane(updates: updates)),
        ] {
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func tab(_ label: String, symbol: String, _ pane: some View) -> NSTabViewItem {
        let controller = NSHostingController(rootView: pane)
        // The window takes each pane's size as its tab is selected.
        controller.sizingOptions = .preferredContentSize
        controller.title = label
        let item = NSTabViewItem(viewController: controller)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }
}
