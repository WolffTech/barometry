// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

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
    private let keepAwake = KeepAwake()
    private let panel: DashboardPanel
    private var slots: [Slot] = []
    private var itemLayout: ItemLayout?

    init(preferences: Preferences, openSettings: @escaping () -> Void) {
        self.preferences = preferences
        monitor = SystemMonitor(interval: preferences.refreshInterval.duration)
        panel = DashboardPanel(monitor: monitor, preferences: preferences, keepAwake: keepAwake, openSettings: openSettings)
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
        let wanted = ItemLayout(layout: preferences.menuBarLayout, style: preferences.menuBarStyle, modules: shownModules)
        if wanted != itemLayout {
            rebuildItems(wanted)
        }
        keepAwake.cursorNudgeInterval = preferences.movesCursorWhenIdle ? preferences.cursorNudgeInterval : nil
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
        self.itemLayout = itemLayout
        let modules = itemLayout.modules
        let wanted: [(autosaveName: String, accessibilityLabel: String, modules: [MenuBarModule])] = switch itemLayout.layout {
        case .individual:
            // New status items appear to the left of existing ones, so create them in
            // reverse to get the modules in order. The autosave name keeps ⌘-drag positions.
            modules.reversed().map { ("barometry.\($0.rawValue)", $0.name, [$0]) }
        case .combined:
            [("barometry.combined", "Barometry", modules)]
        }
        // Items still wanted stay put, so Keep Awake coming and going doesn't recreate the rest.
        // Removed items keep their autosaved positions, so rebuilding doesn't undo ⌘-drags.
        var unused = Dictionary(uniqueKeysWithValues: slots.compactMap { slot in slot.item.autosaveName.map { ($0, slot.item) } })
        slots = wanted.map { wanted in
            let item = unused.removeValue(forKey: wanted.autosaveName)
                ?? makeItem(autosaveName: wanted.autosaveName, accessibilityLabel: wanted.accessibilityLabel)
            // A new slot starts without rendered content, so a style change redraws the item.
            return Slot(item: item, style: itemLayout.style, modules: wanted.modules)
        }
        for item in unused.values {
            NSStatusBar.system.removeStatusItem(item)
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

    /// What a module's widget shows now. Reads observable state, so a SwiftUI view that
    /// calls it updates with each reading.
    func widgetContent(for module: MenuBarModule, style: MenuBarStyle) -> MenuBarWidgetContent {
        monitor.widgetContent(for: module, style: style, temperatureUnit: preferences.temperatureUnit)
    }

    /// The modules in the menu bar now, which include Keep Awake only while it's on.
    /// Reads observable state, like `widgetContent`.
    var shownModules: [MenuBarModule] {
        preferences.menuBarModules.shown(isKeepingAwake: keepAwake.isEnabled)
    }

    /// Modules sorted by where their individual items sit in the menu bar, left to right,
    /// since ⌘-drags rather than the module order place them. Modules without an item yet
    /// keep their relative order at the end.
    func sortedByMenuBarPosition(_ modules: [MenuBarModule]) -> [MenuBarModule] {
        var positions: [MenuBarModule: CGFloat] = [:]
        for slot in slots where slot.modules.count == 1 {
            if let frame = slot.item.button?.window?.frame {
                positions[slot.modules[0]] = frame.minX
            }
        }
        return modules.enumerated()
            .sorted { (positions[$0.element] ?? .infinity, $0.offset) < (positions[$1.element] ?? .infinity, $1.offset) }
            .map(\.element)
    }

    private func renderItems() {
        for index in slots.indices {
            let modules = slots[index].modules
            let style = slots[index].style
            let content = modules.map { widgetContent(for: $0, style: style) }
            guard content != slots[index].renderedContent, let button = slots[index].item.button else { continue }

            let renderer = slots[index].renderer
            renderer.content = MenuBarItemView(style: style, widgets: Array(zip(modules, content)))
            let scale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            guard let image = Self.image(from: renderer, scale: scale) else { continue }
            button.image = image
            slots[index].renderedContent = content
        }
    }

    /// Draws into a CPU bitmap. `ImageRenderer.nsImage` renders on the GPU, which holds
    /// about 100 MB of graphics memory for a tiny image.
    private static func image(from renderer: ImageRenderer<MenuBarItemView>, scale: CGFloat) -> NSImage? {
        var image: NSImage?
        renderer.render { size, draw in
            guard let context = CGContext(
                data: nil,
                width: Int((size.width * scale).rounded(.up)),
                height: Int((size.height * scale).rounded(.up)),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.scaleBy(x: scale, y: scale)
            draw(context)
            guard let cgImage = context.makeImage() else { return }
            image = NSImage(cgImage: cgImage, size: size)
        }
        image?.isTemplate = true
        return image
    }

    /// An individual module's item opens with its details pinned; the combined item opens without details.
    /// ⌥-clicking any item toggles Keep Awake instead.
    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            keepAwake.toggle()
            return
        }
        let modules = slots.first { $0.item.button === sender }?.modules ?? []
        let section = modules.count == 1 ? modules.first.map(DashboardSection.init) : nil
        panel.toggle(below: sender, showing: section)
    }
}
