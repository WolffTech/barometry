import AppKit
import BarometryKit
import SwiftUI

/// Owns the menu bar items, keeps their widgets current, and toggles the dashboard on click.
final class StatusItemController: NSObject {
    /// Sample faster while the dashboard is open so its graphs feel live.
    private static let idleInterval = Duration.seconds(2)
    private static let dashboardInterval = Duration.seconds(1)

    /// A status item and the modules drawn into it.
    private struct Slot {
        let item: NSStatusItem
        let modules: [MenuBarModule]
        var renderedContent: [MenuBarWidgetContent]?
    }

    private let monitor = SystemMonitor(interval: idleInterval)
    private let panel: DashboardPanel
    private var slots: [Slot] = []

    override init() {
        panel = DashboardPanel(monitor: monitor)
        super.init()
        panel.onVisibilityChange = { [monitor] isVisible in
            monitor.interval = isVisible ? Self.dashboardInterval : Self.idleInterval
        }

        // Settings replaces this defaults read in a later milestone. Until then:
        // defaults write tech.wolff.barometry menuBarLayout combined
        let layout = UserDefaults.standard.string(forKey: "menuBarLayout").flatMap(MenuBarLayout.init(rawValue:)) ?? .individual
        buildItems(layout: layout, modules: MenuBarModule.allCases)

        monitor.start()
        observeMonitor()
    }

    private func buildItems(layout: MenuBarLayout, modules: [MenuBarModule]) {
        switch layout {
        case .individual:
            // New status items appear to the left of existing ones, so create them in
            // reverse to get the modules in order. The autosave name keeps ⌘-drag positions.
            slots = modules.reversed().map { module in
                Slot(item: makeItem(autosaveName: "barometry.\(module.rawValue)", accessibilityLabel: module.name), modules: [module])
            }
        case .combined:
            slots = [Slot(item: makeItem(autosaveName: "barometry.combined", accessibilityLabel: "Barometry"), modules: modules)]
        }
    }

    private func makeItem(autosaveName: String, accessibilityLabel: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = autosaveName
        if let button = item.button {
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel(accessibilityLabel)
            button.target = self
            button.action = #selector(togglePanel(_:))
        }
        return item
    }

    /// Re-renders whenever the monitor publishes new readings.
    private func observeMonitor() {
        withObservationTracking {
            renderItems()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeMonitor() }
        }
    }

    private func renderItems() {
        for index in slots.indices {
            let modules = slots[index].modules
            let content = modules.map { monitor.widgetContent(for: $0) }
            guard content != slots[index].renderedContent, let button = slots[index].item.button else { continue }

            let view = MenuBarItemView(widgets: Array(zip(modules, content)))
            let renderer = ImageRenderer(content: view)
            renderer.scale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            guard let image = renderer.nsImage else { continue }
            image.isTemplate = true
            button.image = image
            slots[index].renderedContent = content
        }
    }

    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        panel.toggle(below: sender)
    }
}
