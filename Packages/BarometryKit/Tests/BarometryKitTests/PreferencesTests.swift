import Foundation
import Testing
@testable import BarometryKit

// One shared suite, cleared before each test, so runs don't leave a plist per test behind.
@MainActor
@Suite(.serialized)
struct PreferencesTests {
    private static let suiteName = "tech.wolff.barometry.tests"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)
    }

    @Test func changesPersistAcrossInstances() {
        let preferences = Preferences(defaults: defaults)
        preferences.menuBarLayout = .combined
        preferences.menuBarStyle = .text
        preferences.menuBarModules.move(.battery, by: -10)
        preferences.menuBarModules.setVisible(false, for: .gpu)
        preferences.refreshInterval = .fiveSeconds
        preferences.temperatureUnit = .fahrenheit
        preferences.networkInterface = .named("en0")
        preferences.hiddenDashboardSections = [.disk]

        let reloaded = Preferences(defaults: defaults)

        #expect(reloaded.menuBarLayout == .combined)
        #expect(reloaded.menuBarStyle == .text)
        #expect(reloaded.menuBarModules.visible == [.battery, .cpu, .memory, .network, .sensors])
        #expect(reloaded.refreshInterval == .fiveSeconds)
        #expect(reloaded.temperatureUnit == .fahrenheit)
        #expect(reloaded.networkInterface == .named("en0"))
        #expect(reloaded.hiddenDashboardSections == [.disk])
    }

    @Test func automaticInterfaceClearsTheStoredName() {
        let preferences = Preferences(defaults: defaults)
        preferences.networkInterface = .named("en0")
        preferences.networkInterface = .automatic

        #expect(Preferences(defaults: defaults).networkInterface == .automatic)
    }

    @Test(arguments: [("en_US", TemperatureUnit.fahrenheit), ("en_GB", .celsius)])
    func temperatureUnitDefaultsToTheLocale(identifier: String, expected: TemperatureUnit) {
        #expect(Preferences(defaults: defaults, locale: Locale(identifier: identifier)).temperatureUnit == expected)
    }

    @Test func storedModuleOrderIsRepairedToContainEveryModuleOnce() {
        defaults.set(["battery", "cpu", "battery", "removed"], forKey: "menuBarModuleOrder")

        let order = Preferences(defaults: defaults).menuBarModules.order

        #expect(order == [.battery, .cpu, .gpu, .memory, .network, .sensors])
    }
}

struct MenuBarModuleSelectionTests {
    @Test func lastVisibleModuleCannotBeHidden() {
        var selection = MenuBarModuleSelection(hidden: [.gpu, .memory, .network, .sensors, .battery])
        selection.setVisible(false, for: .cpu)

        #expect(selection.visible == [.cpu])
    }

    @Test func hidingEveryModuleShowsThemAll() {
        let selection = MenuBarModuleSelection(hidden: Set(MenuBarModule.allCases))

        #expect(selection.visible == MenuBarModule.allCases)
    }

    @Test func moveStopsAtTheEnds() {
        var selection = MenuBarModuleSelection()
        selection.move(.gpu, by: -5)
        selection.move(.memory, by: 1)

        #expect(selection.order == [.gpu, .cpu, .network, .memory, .sensors, .battery])
    }
}
