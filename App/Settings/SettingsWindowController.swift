import AppKit
import BarometryKit
import SwiftUI

final class SettingsWindowController {
    private let preferences: Preferences
    private let updates: UpdateController
    private var window: NSWindow?

    init(preferences: Preferences, updates: UpdateController) {
        self.preferences = preferences
        self.updates = updates
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // Barometry has no Dock icon, so bring it forward or the window opens behind others.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(preferences: preferences, updates: updates)))
        window.title = "Barometry Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
