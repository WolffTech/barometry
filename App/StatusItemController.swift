import AppKit
import BarometryKit
import SwiftUI

/// Owns the menu bar items, keeps their widgets current, and toggles the dashboard on click.
final class StatusItemController: NSObject {
    /// Sample faster while the dashboard is open so its graphs feel live.
    private static let dashboardInterval = Duration.seconds(1)

    /// Which status items exist; they're rebuilt when this changes.
    private struct ItemLayout: Equatable {
        let layout: MenuBarLayout
        /// Part of the layout so a style change rebuilds the items, which clears their rendered
        /// content. Network content is the same in both styles but drops its label in text.
        let style: MenuBarStyle
        let modules: [MenuBarModule]
    }

    /// A status item and the modules drawn into it.
    private struct Slot {
        let item: NSStatusItem
        let style: MenuBarStyle
        let modules: [MenuBarModule]
        /// Reused across renders so SwiftUI updates one view graph instead of building a new one each tick.
        let renderer = ImageRenderer(content: MenuBarItemView(style: .graphical, widgets: []))
        var renderedContent: [MenuBarWidgetContent]?

        init(item: NSStatusItem, style: MenuBarStyle, modules: [MenuBarModule]) {
            self.item = item
            self.style = style
            self.modules = modules
        }
    }

    private let preferences: Preferences
    private let monitor: SystemMonitor
    private let panel: DashboardPanel
    private var slots: [Slot] = []
    private var itemLayout: ItemLayout?

    init(preferences: Preferences, openSettings: @escaping () -> Void) {
        self.preferences = preferences
        monitor = SystemMonitor(interval: preferences.refreshInterval.duration)
        panel = DashboardPanel(monitor: monitor, preferences: preferences, openSettings: openSettings)
        super.init()
        panel.onVisibilityChange = { [monitor, preferences] isVisible in
            monitor.interval = isVisible ? Self.dashboardInterval : preferences.refreshInterval.duration
        }
        monitor.networkInterface = preferences.networkInterface.bsdName
        monitor.start()
        observe()
    }

    /// Applies preference changes and re-renders whenever the monitor publishes new readings.
    private func observe() {
        withObservationTracking {
            applyPreferences()
            renderItems()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func applyPreferences() {
        let wanted = ItemLayout(layout: preferences.menuBarLayout, style: preferences.menuBarStyle, modules: preferences.menuBarModules.visible)
        if wanted != itemLayout {
            rebuildItems(wanted)
        }
        let interface = preferences.networkInterface.bsdName
        if monitor.networkInterface != interface {
            monitor.networkInterface = interface
        }
        let interval = preferences.refreshInterval.duration
        if !panel.isVisible, monitor.interval != interval {
            monitor.interval = interval
        }
    }

    private func rebuildItems(_ itemLayout: ItemLayout) {
        // Removed items keep their autosaved positions, so rebuilding doesn't undo ⌘-drags.
        for slot in slots {
            NSStatusBar.system.removeStatusItem(slot.item)
        }
        self.itemLayout = itemLayout
        let modules = itemLayout.modules
        switch itemLayout.layout {
        case .individual:
            // New status items appear to the left of existing ones, so create them in
            // reverse to get the modules in order. The autosave name keeps ⌘-drag positions.
            slots = modules.reversed().map { module in
                Slot(item: makeItem(autosaveName: "barometry.\(module.rawValue)", accessibilityLabel: module.name), style: itemLayout.style, modules: [module])
            }
        case .combined:
            slots = [Slot(item: makeItem(autosaveName: "barometry.combined", accessibilityLabel: "Barometry"), style: itemLayout.style, modules: modules)]
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

    private func renderItems() {
        for index in slots.indices {
            let modules = slots[index].modules
            let style = slots[index].style
            let content = modules.map { monitor.widgetContent(for: $0, style: style, temperatureUnit: preferences.temperatureUnit) }
            guard content != slots[index].renderedContent, let button = slots[index].item.button else { continue }

            let renderer = slots[index].renderer
            renderer.content = MenuBarItemView(style: style, widgets: Array(zip(modules, content)))
            renderer.scale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            guard let image = renderer.nsImage else { continue }
            image.isTemplate = true
            button.image = image
            slots[index].renderedContent = content
        }
    }

    /// An individual module's item opens with its row expanded; the combined item opens collapsed.
    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        let modules = slots.first { $0.item.button === sender }?.modules ?? []
        let section = modules.count == 1 ? modules.first.map(DashboardSection.init) : nil
        panel.toggle(below: sender, expanding: section)
    }
}
