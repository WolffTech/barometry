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
