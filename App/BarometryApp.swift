import AppKit
import BarometryKit

/// AppKit entry point. A SwiftUI `App` would need a scene, and its `Settings` scene can't
/// be opened reliably from the dashboard panel, so Barometry manages its own windows.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences(
        unavailableMenuBarModules: MenuBarModule.unavailableOnThisMac(),
        unavailableDashboardSections: DashboardSection.unavailableOnThisMac()
    )
    private var statusItemController: StatusItemController?
    private lazy var settingsWindow = SettingsWindowController(preferences: preferences)

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        statusItemController = StatusItemController(preferences: preferences) { [weak self] in
            self?.openSettings()
        }
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    /// Never shown (Barometry is a UI element app), but supplies ⌘, ⌘Q, and ⌘W while
    /// Barometry is active.
    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Barometry", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let mainMenu = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        return mainMenu
    }
}
