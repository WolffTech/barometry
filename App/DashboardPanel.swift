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

    /// Where the panel hangs while open: its top edge and horizontal position stay put as
    /// its height follows the content.
    private struct Placement {
        let top: CGFloat
        let minX: CGFloat
        let width: CGFloat
        let maximumHeight: CGFloat
    }

    private let monitor: SystemMonitor
    private let preferences: Preferences
    private let machine = Machine.current()
    private let openSettings: () -> Void
    private var outsideClickMonitor: Any?
    private var placement: Placement?

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

    /// Opens with `section` expanded, if given.
    func toggle(below button: NSStatusBarButton, expanding section: DashboardSection?) {
        if isVisible {
            dismiss()
        } else {
            show(below: button, expanding: section)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    private func show(below button: NSStatusBarButton, expanding section: DashboardSection?) {
        guard let buttonWindow = button.window, let screen = buttonWindow.screen else { return }
        let interfaceNames = Dictionary(
            NetworkInterfaces.available().map { ($0.bsdName, $0.displayName) },
            uniquingKeysWith: { first, _ in first }
        )
        let actions = DashboardView.Actions(
            openActivityMonitor: { [weak self] in
                self?.dismiss()
                Self.openActivityMonitor()
            },
            openSettings: { [weak self] in
                self?.dismiss()
                self?.openSettings()
            },
            contentHeightChanged: { [weak self] height in
                self?.fit(contentHeight: height)
            }
        )
        // Hosted only while open: a hidden hosting view still re-lays out on every reading.
        let dashboard = DashboardView(
            monitor: monitor,
            preferences: preferences,
            machine: machine,
            interfaceNames: interfaceNames,
            expanded: section,
            actions: actions
        )
        let contentView = NSHostingView(rootView: dashboard)
        let ideal = contentView.fittingSize
        // The panel sizes itself in `fit(contentHeight:)` so its top edge stays under the menu bar.
        contentView.sizingOptions = []
        self.contentView = contentView

        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let top = anchor.minY - Self.gapBelowMenuBar
        let minX = min(
            max(anchor.midX - ideal.width / 2, visible.minX + Self.screenMargin),
            visible.maxX - ideal.width - Self.screenMargin
        )
        // Cap the height to the screen; the dashboard scrolls when capped.
        placement = Placement(top: top, minX: minX, width: ideal.width, maximumHeight: top - visible.minY - Self.screenMargin)
        fit(contentHeight: ideal.height)
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
        placement = nil
        onVisibilityChange?(false)
    }

    /// Resizes to fit the content, up to the screen height, keeping the top edge in place.
    private func fit(contentHeight: CGFloat) {
        guard let placement else { return }
        let height = min(contentHeight.rounded(.up), placement.maximumHeight)
        let target = NSRect(x: placement.minX, y: placement.top - height, width: placement.width, height: height)
        guard target != frame else { return }
        if isVisible {
            // Roughly matches the row's expand animation.
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                animator().setFrame(target, display: true)
            }
        } else {
            setFrame(target, display: true)
        }
    }

    private static func openActivityMonitor() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
