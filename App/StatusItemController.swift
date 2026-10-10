import AppKit
import BarometryKit

/// Owns the menu bar item and toggles the dashboard when it is clicked.
final class StatusItemController: NSObject {
    /// Sample faster while the dashboard is open so its graphs feel live.
    private static let idleInterval = Duration.seconds(2)
    private static let dashboardInterval = Duration.seconds(1)

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor = SystemMonitor(interval: idleInterval)
    private let panel: DashboardPanel

    override init() {
        panel = DashboardPanel(monitor: monitor)
        super.init()
        panel.onVisibilityChange = { [monitor] isVisible in
            monitor.interval = isVisible ? Self.dashboardInterval : Self.idleInterval
        }
        monitor.start()

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
