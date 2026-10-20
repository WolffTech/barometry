// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Observation

/// User settings, persisted to `UserDefaults` as they change.
@MainActor
@Observable
public final class Preferences {
    public var menuBarLayout: MenuBarLayout {
        didSet { defaults.set(menuBarLayout.rawValue, forKey: Key.menuBarLayout) }
    }

    public var menuBarStyle: MenuBarStyle {
        didSet { defaults.set(menuBarStyle.rawValue, forKey: Key.menuBarStyle) }
    }

    public var menuBarModules: MenuBarModuleSelection {
        didSet {
            defaults.set(menuBarModules.order.map(\.rawValue), forKey: Key.menuBarModuleOrder)
            defaults.set(menuBarModules.hidden.map(\.rawValue).sorted(), forKey: Key.hiddenMenuBarModules)
        }
    }

    /// Time between readings while the dashboard is closed.
    public var refreshInterval: RefreshInterval {
        didSet { defaults.set(refreshInterval.rawValue, forKey: Key.refreshInterval) }
    }

    public var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Key.temperatureUnit) }
    }

    public var networkInterface: NetworkInterfaceChoice {
        didSet {
            switch networkInterface {
            case .automatic: defaults.removeObject(forKey: Key.networkInterface)
            case .named(let name): defaults.set(name, forKey: Key.networkInterface)
            }
        }
    }

    public var dashboardStyle: DashboardStyle {
        didSet { defaults.set(dashboardStyle.rawValue, forKey: Key.dashboardStyle) }
    }

    /// Every dashboard section exactly once, hidden ones included. Change it with
    /// `moveDashboardSections(fromOffsets:toOffset:)`.
    public private(set) var dashboardSectionOrder: [DashboardSection] {
        didSet { defaults.set(dashboardSectionOrder.map(\.rawValue), forKey: Key.dashboardSectionOrder) }
    }

    public var hiddenDashboardSections: Set<DashboardSection> {
        didSet { defaults.set(hiddenDashboardSections.map(\.rawValue).sorted(), forKey: Key.hiddenDashboardSections) }
    }

    /// Whether Keep Awake also nudges the cursor after `cursorNudgeInterval` of idle input.
    public var movesCursorWhenIdle: Bool {
        didSet { defaults.set(movesCursorWhenIdle, forKey: Key.movesCursorWhenIdle) }
    }

    public var cursorNudgeInterval: CursorNudgeInterval {
        didSet { defaults.set(cursorNudgeInterval.rawValue, forKey: Key.cursorNudgeInterval) }
    }

    /// Whether Keep Awake turns off at `lowBatteryCutoff` while on battery power.
    public var keepAwakeStopsOnLowBattery: Bool {
        didSet { defaults.set(keepAwakeStopsOnLowBattery, forKey: Key.keepAwakeStopsOnLowBattery) }
    }

    public var lowBatteryCutoff: LowBatteryCutoff {
        didSet { defaults.set(lowBatteryCutoff.percent, forKey: Key.lowBatteryCutoff) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// The unavailable modules are ones this Mac can't show, such as battery on a desktop.
    public init(
        defaults: UserDefaults = .standard,
        unavailableMenuBarModules: Set<MenuBarModule> = []
    ) {
        self.defaults = defaults
        menuBarLayout = defaults.string(forKey: Key.menuBarLayout).flatMap(MenuBarLayout.init(rawValue:)) ?? .individual
        menuBarStyle = defaults.string(forKey: Key.menuBarStyle).flatMap(MenuBarStyle.init(rawValue:)) ?? .graphical
        menuBarModules = MenuBarModuleSelection(
            order: Self.decode(defaults.stringArray(forKey: Key.menuBarModuleOrder)) ?? MenuBarModule.allCases,
            hidden: Set(Self.decode(defaults.stringArray(forKey: Key.hiddenMenuBarModules)) ?? []),
            unavailable: unavailableMenuBarModules
        )
        refreshInterval = RefreshInterval(rawValue: defaults.integer(forKey: Key.refreshInterval)) ?? .twoSeconds
        temperatureUnit = defaults.string(forKey: Key.temperatureUnit).flatMap(TemperatureUnit.init(rawValue:)) ?? .celsius
        networkInterface = defaults.string(forKey: Key.networkInterface).map(NetworkInterfaceChoice.named) ?? .automatic
        dashboardStyle = defaults.string(forKey: Key.dashboardStyle).flatMap(DashboardStyle.init(rawValue:)) ?? .cluster
        dashboardSectionOrder = Self.complete(Self.decode(defaults.stringArray(forKey: Key.dashboardSectionOrder)) ?? [])
        hiddenDashboardSections = Set(Self.decode(defaults.stringArray(forKey: Key.hiddenDashboardSections)) ?? [])
        movesCursorWhenIdle = defaults.bool(forKey: Key.movesCursorWhenIdle)
        cursorNudgeInterval = CursorNudgeInterval(rawValue: defaults.integer(forKey: Key.cursorNudgeInterval)) ?? .oneMinute
        keepAwakeStopsOnLowBattery = defaults.object(forKey: Key.keepAwakeStopsOnLowBattery) as? Bool ?? true
        lowBatteryCutoff = (defaults.object(forKey: Key.lowBatteryCutoff) as? Int).map(LowBatteryCutoff.init(percent:)) ?? .default
    }

    /// Moves sections the way SwiftUI's `onMove` reports a drag.
    public func moveDashboardSections(fromOffsets source: IndexSet, toOffset destination: Int) {
        dashboardSectionOrder.move(fromOffsets: source, toOffset: destination)
    }

    /// Drops duplicates and appends cases missing from a stored order, such as ones added
    /// in a later version.
    nonisolated static func complete<Value: CaseIterable & Hashable>(_ order: [Value]) -> [Value] {
        var seen = Set<Value>()
        return (order + Value.allCases).filter { seen.insert($0).inserted }
    }

    /// Raw values that no longer match a case, such as a removed module, are dropped.
    private static func decode<Value: RawRepresentable<String>>(_ rawValues: [String]?) -> [Value]? {
        rawValues?.compactMap(Value.init(rawValue:))
    }

    private enum Key {
        static let menuBarLayout = "menuBarLayout"
        static let menuBarStyle = "menuBarStyle"
        static let menuBarModuleOrder = "menuBarModuleOrder"
        static let hiddenMenuBarModules = "hiddenMenuBarModules"
        static let refreshInterval = "refreshInterval"
        static let temperatureUnit = "temperatureUnit"
        static let networkInterface = "networkInterface"
        static let dashboardStyle = "dashboardStyle"
        static let dashboardSectionOrder = "dashboardSectionOrder"
        static let hiddenDashboardSections = "hiddenDashboardSections"
        static let movesCursorWhenIdle = "movesCursorWhenIdle"
        static let cursorNudgeInterval = "cursorNudgeInterval"
        static let keepAwakeStopsOnLowBattery = "keepAwakeStopsOnLowBattery"
        static let lowBatteryCutoff = "lowBatteryCutoff"
    }
}

/// Every menu bar module exactly once, in display order, with at least one visible module
/// that doesn't depend on Keep Awake, so there's always an item to click.
public struct MenuBarModuleSelection: Equatable, Sendable {
    public private(set) var order: [MenuBarModule]
    /// The user's choice, kept separate from `unavailable` so it survives a move to a Mac
    /// that has the hardware.
    public private(set) var hidden: Set<MenuBarModule>
    /// Modules this Mac can't show, such as battery on a desktop. They're never visible.
    public let unavailable: Set<MenuBarModule>

    public init(
        order: [MenuBarModule] = MenuBarModule.allCases,
        hidden: Set<MenuBarModule> = [],
        unavailable: Set<MenuBarModule> = []
    ) {
        self.order = Preferences.complete(order)
        let unavailable = Self.leavesItemToClick(hidden: [], unavailable: unavailable) ? unavailable : []
        self.unavailable = unavailable
        self.hidden = Self.leavesItemToClick(hidden: hidden, unavailable: unavailable) ? hidden : []
    }

    /// The modules the user chose to show, including Keep Awake whether or not it's on.
    public var visible: [MenuBarModule] {
        order.filter(isVisible)
    }

    /// The modules in the menu bar right now.
    public func shown(isKeepingAwake: Bool) -> [MenuBarModule] {
        visible.filter { isKeepingAwake || !$0.showsOnlyWhileKeepingAwake }
    }

    public func isVisible(_ module: MenuBarModule) -> Bool {
        isAvailable(module) && !hidden.contains(module)
    }

    public func isAvailable(_ module: MenuBarModule) -> Bool {
        !unavailable.contains(module)
    }

    /// False for the last visible module that shows regardless of Keep Awake.
    public func canHide(_ module: MenuBarModule) -> Bool {
        Self.leavesItemToClick(hidden: hidden.union([module]), unavailable: unavailable)
    }

    /// Showing an unavailable module and hiding a module that `canHide` refuses are ignored.
    public mutating func setVisible(_ isVisible: Bool, for module: MenuBarModule) {
        guard isAvailable(module) else { return }
        if isVisible {
            hidden.remove(module)
        } else if canHide(module) {
            hidden.insert(module)
        }
    }

    private static func leavesItemToClick(hidden: Set<MenuBarModule>, unavailable: Set<MenuBarModule>) -> Bool {
        MenuBarModule.allCases.contains { module in
            !module.showsOnlyWhileKeepingAwake && !hidden.contains(module) && !unavailable.contains(module)
        }
    }

    /// Moves modules the way SwiftUI's `onMove` reports a drag.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
    }
}

extension Array {
    /// Matches SwiftUI's `move(fromOffsets:toOffset:)`, which BarometryKit can't import:
    /// `destination` is an index in the array before the move. Out-of-range offsets are ignored.
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let source = source.filter(indices.contains)
        guard (0...count).contains(destination) else { return }
        let moving = source.map { self[$0] }
        let insertion = destination - source.count(where: { $0 < destination })
        for index in source.reversed() {
            remove(at: index)
        }
        insert(contentsOf: moving, at: insertion)
    }
}

public enum RefreshInterval: Int, CaseIterable, Sendable, Identifiable {
    case oneSecond = 1
    case twoSeconds = 2
    case fiveSeconds = 5

    public var id: Int { rawValue }
    public var duration: Duration { .seconds(rawValue) }
}

/// Idle time before Keep Awake nudges the cursor. The longest stays under the five minutes
/// after which apps such as Microsoft Teams mark someone away.
public enum CursorNudgeInterval: Int, CaseIterable, Sendable, Identifiable {
    case thirtySeconds = 30
    case oneMinute = 60
    case twoMinutes = 120
    case fourMinutes = 240

    public var id: Int { rawValue }
    public var duration: Duration { .seconds(rawValue) }
}

public enum TemperatureUnit: String, CaseIterable, Sendable, Identifiable {
    case celsius
    case fahrenheit

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .celsius: "°C"
        case .fahrenheit: "°F"
        }
    }

    var unit: UnitTemperature {
        switch self {
        case .celsius: .celsius
        case .fahrenheit: .fahrenheit
        }
    }
}

public enum NetworkInterfaceChoice: Hashable, Sendable {
    /// The interface carrying the default route.
    case automatic
    /// A BSD interface name such as "en0".
    case named(String)

    public var bsdName: String? {
        switch self {
        case .automatic: nil
        case .named(let name): name
        }
    }
}

/// How the dashboard lays out its sections.
public enum DashboardStyle: String, CaseIterable, Sendable, Identifiable {
    /// Dials and tiles.
    case cluster
    /// One row per section, each with a sparkline.
    case glance

    public var id: String { rawValue }
}

/// A part of the dashboard: a row in the glance style, or one or more tiles in the cluster style.
public enum DashboardSection: String, CaseIterable, Sendable, Identifiable {
    case cpu
    case gpu
    case memory
    case network
    /// System power, battery, temperatures, and fans.
    case power
    case disk

    public var id: String { rawValue }

    /// The row that details a menu bar module.
    public init(_ module: MenuBarModule) {
        switch module {
        case .cpu: self = .cpu
        case .gpu: self = .gpu
        case .memory: self = .memory
        case .network: self = .network
        case .sensors, .battery, .keepAwake: self = .power
        }
    }

    public var name: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "Memory"
        case .network: "Network"
        case .power: "Power"
        case .disk: "Disk"
        }
    }
}
