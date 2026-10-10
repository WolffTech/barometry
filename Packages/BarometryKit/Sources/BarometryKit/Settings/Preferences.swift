import Foundation
import Observation

/// User settings, persisted to `UserDefaults` as they change.
@MainActor
@Observable
public final class Preferences {
    public var menuBarLayout: MenuBarLayout {
        didSet { defaults.set(menuBarLayout.rawValue, forKey: Key.menuBarLayout) }
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

    public var hiddenDashboardSections: Set<DashboardSection> {
        didSet { defaults.set(hiddenDashboardSections.map(\.rawValue).sorted(), forKey: Key.hiddenDashboardSections) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard, locale: Locale = .autoupdatingCurrent) {
        self.defaults = defaults
        menuBarLayout = defaults.string(forKey: Key.menuBarLayout).flatMap(MenuBarLayout.init(rawValue:)) ?? .individual
        menuBarModules = MenuBarModuleSelection(
            order: Self.decode(defaults.stringArray(forKey: Key.menuBarModuleOrder)) ?? MenuBarModule.allCases,
            hidden: Set(Self.decode(defaults.stringArray(forKey: Key.hiddenMenuBarModules)) ?? [])
        )
        refreshInterval = RefreshInterval(rawValue: defaults.integer(forKey: Key.refreshInterval)) ?? .twoSeconds
        temperatureUnit = defaults.string(forKey: Key.temperatureUnit).flatMap(TemperatureUnit.init(rawValue:))
            ?? (locale.measurementSystem == .us ? .fahrenheit : .celsius)
        networkInterface = defaults.string(forKey: Key.networkInterface).map(NetworkInterfaceChoice.named) ?? .automatic
        hiddenDashboardSections = Set(Self.decode(defaults.stringArray(forKey: Key.hiddenDashboardSections)) ?? [])
    }

    /// Raw values that no longer match a case, such as a removed module, are dropped.
    private static func decode<Value: RawRepresentable<String>>(_ rawValues: [String]?) -> [Value]? {
        rawValues?.compactMap(Value.init(rawValue:))
    }

    private enum Key {
        static let menuBarLayout = "menuBarLayout"
        static let menuBarModuleOrder = "menuBarModuleOrder"
        static let hiddenMenuBarModules = "hiddenMenuBarModules"
        static let refreshInterval = "refreshInterval"
        static let temperatureUnit = "temperatureUnit"
        static let networkInterface = "networkInterface"
        static let hiddenDashboardSections = "hiddenDashboardSections"
    }
}

/// Every menu bar module exactly once, in display order, with at least one visible so
/// there's always an item to click.
public struct MenuBarModuleSelection: Equatable, Sendable {
    public private(set) var order: [MenuBarModule]
    public private(set) var hidden: Set<MenuBarModule>

    public init(order: [MenuBarModule] = MenuBarModule.allCases, hidden: Set<MenuBarModule> = []) {
        // Drop duplicates and append modules missing from a stored order, such as ones
        // added in a later version.
        var seen = Set<MenuBarModule>()
        self.order = (order + MenuBarModule.allCases).filter { seen.insert($0).inserted }
        self.hidden = hidden.count < MenuBarModule.allCases.count ? hidden : []
    }

    public var visible: [MenuBarModule] {
        order.filter { !hidden.contains($0) }
    }

    public func isVisible(_ module: MenuBarModule) -> Bool {
        !hidden.contains(module)
    }

    /// Hiding the last visible module is ignored.
    public mutating func setVisible(_ isVisible: Bool, for module: MenuBarModule) {
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

public enum DashboardSection: String, CaseIterable, Sendable, Identifiable {
    case battery
    case cpu
    case cores
    case gpu
    case memory
    case sensors
    case network
    case disk

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .battery: "Battery"
        case .cpu: "CPU"
        case .cores: "Cores"
        case .gpu: "GPU"
        case .memory: "Memory"
        case .sensors: "Sensors"
        case .network: "Network"
        case .disk: "Disk"
        }
    }
}
