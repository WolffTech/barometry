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

    @ObservationIgnored private let defaults: UserDefaults

    /// The unavailable modules are ones this Mac can't show, such as battery on a desktop.
    public init(
        defaults: UserDefaults = .standard,
        locale: Locale = .autoupdatingCurrent,
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
        temperatureUnit = defaults.string(forKey: Key.temperatureUnit).flatMap(TemperatureUnit.init(rawValue:))
            ?? (locale.measurementSystem == .us ? .fahrenheit : .celsius)
        networkInterface = defaults.string(forKey: Key.networkInterface).map(NetworkInterfaceChoice.named) ?? .automatic
        dashboardStyle = defaults.string(forKey: Key.dashboardStyle).flatMap(DashboardStyle.init(rawValue:)) ?? .cluster
        hiddenDashboardSections = Set(Self.decode(defaults.stringArray(forKey: Key.hiddenDashboardSections)) ?? [])
        movesCursorWhenIdle = defaults.bool(forKey: Key.movesCursorWhenIdle)
        cursorNudgeInterval = CursorNudgeInterval(rawValue: defaults.integer(forKey: Key.cursorNudgeInterval)) ?? .oneMinute
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
        static let hiddenDashboardSections = "hiddenDashboardSections"
        static let movesCursorWhenIdle = "movesCursorWhenIdle"
        static let cursorNudgeInterval = "cursorNudgeInterval"
    }
}

/// Every menu bar module exactly once, in display order, with at least one visible so
/// there's always an item to click.
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
        // Drop duplicates and append modules missing from a stored order, such as ones
        // added in a later version.
        var seen = Set<MenuBarModule>()
        self.order = (order + MenuBarModule.allCases).filter { seen.insert($0).inserted }
        let unavailable = unavailable.count < MenuBarModule.allCases.count ? unavailable : []
        self.unavailable = unavailable
        self.hidden = hidden.union(unavailable).count < MenuBarModule.allCases.count ? hidden : []
    }

    public var visible: [MenuBarModule] {
        order.filter(isVisible)
    }

    public func isVisible(_ module: MenuBarModule) -> Bool {
        isAvailable(module) && !hidden.contains(module)
    }

    public func isAvailable(_ module: MenuBarModule) -> Bool {
        !unavailable.contains(module)
    }

    /// Showing an unavailable module and hiding the last visible module are ignored.
    public mutating func setVisible(_ isVisible: Bool, for module: MenuBarModule) {
        guard isAvailable(module) else { return }
        if isVisible {
            hidden.remove(module)
        } else if visible != [module] {
            hidden.insert(module)
        }
    }

    /// Moves a module earlier (negative offset) or later, stopping at either end.
    public mutating func move(_ module: MenuBarModule, by offset: Int) {
        guard let index = order.firstIndex(of: module) else { return }
        let destination = min(max(index + offset, 0), order.count - 1)
        order.remove(at: index)
        order.insert(module, at: destination)
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
        case .sensors, .battery: self = .power
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
