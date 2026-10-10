import AppKit

/// Owns the menu bar item and toggles the dashboard when it is clicked.
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = DashboardPanel()

    override init() {
        super.init()
        guard let button = statusItem.button else { return }
        // Placeholder until the menu bar widgets milestone.
        button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "Barometry")
        button.target = self
        button.action = #selector(togglePanel(_:))
    }

    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        panel.toggle(below: sender)
    }
}
