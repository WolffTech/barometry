import AppKit
import BarometryKit
import SwiftUI

/// Borderless, arrowless panel anchored under a status item.
/// Closes on a click outside the app, on Esc, or when its status item is clicked again.
final class DashboardPanel: NSPanel {
    private static let gapBelowMenuBar: CGFloat = 6
    private static let screenMargin: CGFloat = 8

    /// Called with `true` when the panel opens and `false` when it closes.
    var onVisibilityChange: ((Bool) -> Void)?

    private let monitor: SystemMonitor
    private let preferences: Preferences
    private let openSettings: () -> Void
    private var outsideClickMonitor: Any?

    init(monitor: SystemMonitor, preferences: Preferences, openSettings: @escaping () -> Void) {
        self.monitor = monitor
        self.preferences = preferences
        self.openSettings = openSettings
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    // Borderless windows refuse key status by default; key status is needed for Esc and ⌘Q.
    override var canBecomeKey: Bool { true }

    func toggle(below button: NSStatusBarButton) {
        if isVisible {
            dismiss()
        } else {
            show(below: button)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    private func show(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window, let screen = buttonWindow.screen else { return }
        // Hosted only while open: a hidden hosting view still re-lays out on every reading.
        let dashboard = DashboardView(monitor: monitor, preferences: preferences) { [weak self] in
            self?.dismiss()
            self?.openSettings()
        }
        let contentView = NSHostingView(rootView: dashboard)
        self.contentView = contentView

        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let ideal = contentView.fittingSize
        // Cap the height to the screen; the dashboard scrolls when capped.
        let maximumHeight = anchor.minY - Self.gapBelowMenuBar - visible.minY - Self.screenMargin
        let size = CGSize(width: ideal.width, height: min(ideal.height, maximumHeight))
        let x = min(
            max(anchor.midX - size.width / 2, visible.minX + Self.screenMargin),
            visible.maxX - size.width - Self.screenMargin
        )
        let y = anchor.minY - Self.gapBelowMenuBar - size.height
        setFrame(NSRect(origin: CGPoint(x: x, y: y), size: size), display: true)
        makeKeyAndOrderFront(nil)

        // Global monitors only see events sent to other apps, so clicks inside the panel
        // or on our own status item don't trigger this.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
        onVisibilityChange?(true)
    }

    private func dismiss() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        orderOut(nil)
        contentView = nil
        onVisibilityChange?(false)
    }
}
