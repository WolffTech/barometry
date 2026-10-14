// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

public enum MenuBarModule: String, CaseIterable, Codable, Sendable, Identifiable {
    case cpu
    case gpu
    case memory
    case network
    case sensors
    case battery

    public var id: String { rawValue }

    /// Short label stacked vertically beside the widget.
    public var label: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "MEM"
        case .network: "NET"
        case .sensors: "SEN"
        case .battery: "BAT"
        }
    }

    /// Modules this Mac lacks the hardware for. Hardware doesn't change while running,
    /// so check once at launch.
    public static func unavailableOnThisMac() -> Set<MenuBarModule> {
        BatterySampler.isInstalled ? [] : [.battery]
    }

    public var name: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "Memory"
        case .network: "Network"
        case .sensors: "Sensors"
        case .battery: "Battery"
        }
    }
}

public enum MenuBarLayout: String, CaseIterable, Codable, Sendable {
    /// One status item per module, reorderable with ⌘-drag.
    case individual
    /// A single status item showing every enabled module side by side.
    case combined
}

public enum MenuBarStyle: String, CaseIterable, Codable, Sendable {
    /// Bar graphs for CPU and GPU and a fill gauge for memory.
    case graphical
    /// Every module as labeled numbers.
    case text
}
