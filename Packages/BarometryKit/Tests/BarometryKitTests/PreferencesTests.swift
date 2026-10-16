// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

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
        preferences.menuBarModules.move(fromOffsets: [5], toOffset: 0)
        preferences.menuBarModules.setVisible(false, for: .gpu)
        preferences.refreshInterval = .fiveSeconds
        preferences.temperatureUnit = .fahrenheit
        preferences.networkInterface = .named("en0")
        preferences.dashboardStyle = .glance
        preferences.moveDashboardSections(fromOffsets: [5], toOffset: 0)
        preferences.hiddenDashboardSections = [.disk]
        preferences.movesCursorWhenIdle = true
        preferences.cursorNudgeInterval = .fourMinutes

        let reloaded = Preferences(defaults: defaults)

        #expect(reloaded.menuBarLayout == .combined)
        #expect(reloaded.menuBarStyle == .text)
        #expect(reloaded.menuBarModules.visible == [.battery, .cpu, .memory, .network, .sensors, .keepAwake])
        #expect(reloaded.refreshInterval == .fiveSeconds)
        #expect(reloaded.temperatureUnit == .fahrenheit)
        #expect(reloaded.networkInterface == .named("en0"))
        #expect(reloaded.dashboardStyle == .glance)
        #expect(reloaded.dashboardSectionOrder == [.disk, .cpu, .gpu, .memory, .network, .power])
        #expect(reloaded.hiddenDashboardSections == [.disk])
        #expect(reloaded.movesCursorWhenIdle)
        #expect(reloaded.cursorNudgeInterval == .fourMinutes)
    }

    @Test func automaticInterfaceClearsTheStoredName() {
        let preferences = Preferences(defaults: defaults)
        preferences.networkInterface = .named("en0")
        preferences.networkInterface = .automatic

        #expect(Preferences(defaults: defaults).networkInterface == .automatic)
    }

    @Test func temperatureUnitDefaultsToCelsius() {
        #expect(Preferences(defaults: defaults).temperatureUnit == .celsius)
    }

    @Test func dashboardStyleDefaultsToTheCluster() {
        #expect(Preferences(defaults: defaults).dashboardStyle == .cluster)
    }

    @Test func cursorNudgingDefaultsToOffWithAOneMinuteInterval() {
        let preferences = Preferences(defaults: defaults)

        #expect(!preferences.movesCursorWhenIdle)
        #expect(preferences.cursorNudgeInterval == .oneMinute)
    }

    @Test func storedModuleOrderIsRepairedToContainEveryModuleOnce() {
        defaults.set(["battery", "cpu", "battery", "removed"], forKey: "menuBarModuleOrder")

        let order = Preferences(defaults: defaults).menuBarModules.order

        #expect(order == [.battery, .cpu, .gpu, .memory, .network, .sensors, .keepAwake])
    }

    @Test func storedDashboardOrderIsRepairedToContainEverySectionOnce() {
        defaults.set(["disk", "cpu", "disk", "removed"], forKey: "dashboardSectionOrder")

        let order = Preferences(defaults: defaults).dashboardSectionOrder

        #expect(order == [.disk, .cpu, .gpu, .memory, .network, .power])
    }
}

struct MenuBarModuleSelectionTests {
    @Test func lastVisibleModuleCannotBeHidden() {
        var selection = MenuBarModuleSelection(hidden: [.gpu, .memory, .network, .sensors, .battery, .keepAwake])
        selection.setVisible(false, for: .cpu)

        #expect(selection.visible == [.cpu])
    }

    // Keep Awake disappears when it's off, which would leave nothing to click.
    @Test func keepAwakeDoesNotCountAsAnItemToClick() {
        var selection = MenuBarModuleSelection(hidden: [.gpu, .memory, .network, .sensors, .battery])
        selection.setVisible(false, for: .cpu)

        #expect(!selection.canHide(.cpu))
        #expect(selection.canHide(.keepAwake))
        #expect(selection.visible == [.cpu, .keepAwake])
    }

    @Test func hidingEveryModuleButKeepAwakeShowsThemAll() {
        let selection = MenuBarModuleSelection(hidden: [.cpu, .gpu, .memory, .network, .sensors, .battery])

        #expect(selection.visible == MenuBarModule.allCases)
    }

    @Test func keepAwakeIsShownOnlyWhileOn() {
        let selection = MenuBarModuleSelection(order: [.keepAwake, .cpu], hidden: [.gpu, .memory, .network, .sensors, .battery])

        #expect(selection.shown(isKeepingAwake: true) == [.keepAwake, .cpu])
        #expect(selection.shown(isKeepingAwake: false) == [.cpu])
    }

    @Test func keepAwakeIsShownWhereverItsOrdered() {
        var selection = MenuBarModuleSelection(unavailable: [.battery])
        selection.move(fromOffsets: [6], toOffset: 1)

        #expect(selection.shown(isKeepingAwake: true) == [.cpu, .keepAwake, .gpu, .memory, .network, .sensors])
    }

    @Test func hidingEveryModuleShowsThemAll() {
        let selection = MenuBarModuleSelection(hidden: Set(MenuBarModule.allCases))

        #expect(selection.visible == MenuBarModule.allCases)
    }

    @Test func unavailableModuleStaysHiddenWithoutChangingTheUsersChoice() {
        var selection = MenuBarModuleSelection(unavailable: [.battery])
        selection.setVisible(true, for: .battery)

        #expect(!selection.visible.contains(.battery))
        #expect(!selection.hidden.contains(.battery))
    }

    @Test func lastAvailableModuleCannotBeHidden() {
        var selection = MenuBarModuleSelection(hidden: [.gpu, .memory, .network, .sensors, .keepAwake], unavailable: [.battery])
        selection.setVisible(false, for: .cpu)

        #expect(selection.visible == [.cpu])
    }

    @Test func hidingEveryAvailableModuleShowsThemAll() {
        let selection = MenuBarModuleSelection(hidden: [.cpu, .gpu, .memory, .network, .sensors], unavailable: [.battery])

        #expect(selection.visible == [.cpu, .gpu, .memory, .network, .sensors, .keepAwake])
    }

    // Destinations are indexes before the move, as SwiftUI's onMove reports them.
    @Test func moveFollowsSwiftUIOffsets() {
        var selection = MenuBarModuleSelection()
        selection.move(fromOffsets: [1], toOffset: 0)
        selection.move(fromOffsets: [2], toOffset: 4)

        #expect(selection.order == [.gpu, .cpu, .network, .memory, .sensors, .battery, .keepAwake])
    }

    @Test func moveOfSeveralKeepsTheirOrder() {
        var selection = MenuBarModuleSelection()
        selection.move(fromOffsets: [0, 2], toOffset: 7)

        #expect(selection.order == [.gpu, .network, .sensors, .battery, .keepAwake, .cpu, .memory])
    }

    @Test func moveIgnoresOutOfRangeOffsets() {
        var selection = MenuBarModuleSelection()
        selection.move(fromOffsets: [9], toOffset: 0)
        selection.move(fromOffsets: [0], toOffset: 9)

        #expect(selection.order == MenuBarModule.allCases)
    }
}
