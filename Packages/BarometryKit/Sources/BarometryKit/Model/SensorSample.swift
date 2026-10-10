public struct Fan: Equatable, Sendable, Identifiable {
    public let id: Int
    /// Current speed; Apple Silicon fans stop entirely at low load.
    public let rpm: Double
    public let maximumRPM: Double?

    public init(id: Int, rpm: Double, maximumRPM: Double?) {
        self.id = id
        self.rpm = rpm
        self.maximumRPM = maximumRPM
    }

    public var isSpinning: Bool {
        rpm >= 1
    }
}

/// Temperatures, power, and fans read from the SMC.
public struct SensorSample: Equatable, Sendable {
    public let cpuTemperature: Temperature?
    public let gpuTemperature: Temperature?
    /// Whole-system power draw, whether from the adapter or the battery.
    public let systemPower: Power?
    public let fans: [Fan]

    public init(cpuTemperature: Temperature?, gpuTemperature: Temperature?, systemPower: Power?, fans: [Fan]) {
        self.cpuTemperature = cpuTemperature
        self.gpuTemperature = gpuTemperature
        self.systemPower = systemPower
        self.fans = fans
    }

    /// Mean of plausible readings. Unused sensors often report 0 or garbage, so values
    /// outside 1–150 °C are dropped.
    static func meanTemperature(_ celsius: some Sequence<Double>) -> Temperature? {
        let valid = celsius.filter { (1...150).contains($0) }
        guard !valid.isEmpty else { return nil }
        return Temperature(celsius: valid.reduce(0, +) / Double(valid.count))
    }
}

public struct GPUSample: Equatable, Sendable {
    public let utilization: Percent
    /// System memory the GPU driver currently has in use.
    public let memoryInUse: ByteCount?

    public init(utilization: Percent, memoryInUse: ByteCount?) {
        self.utilization = utilization
        self.memoryInUse = memoryInUse
    }
}

/// Average clock speed while active, over the last interval. Nil when the unit was idle
/// for the whole interval.
public struct FrequencySample: Equatable, Sendable {
    public let efficiencyCores: Frequency?
    public let performanceCores: Frequency?
    public let gpu: Frequency?
    /// Highest clock in each table, for scaling gauges.
    public let gpuMaximum: Frequency?

    public init(efficiencyCores: Frequency?, performanceCores: Frequency?, gpu: Frequency?, gpuMaximum: Frequency?) {
        self.efficiencyCores = efficiencyCores
        self.performanceCores = performanceCores
        self.gpu = gpu
        self.gpuMaximum = gpuMaximum
    }

    /// The headline CPU clock: performance cores when they ran, otherwise efficiency cores.
    public var cpu: Frequency? {
        performanceCores ?? efficiencyCores
    }
}

/// Converts DVFS state residency into an average active frequency.
enum DVFS {
    /// State names that mean the unit wasn't running.
    static let inactiveStates: Set<String> = ["IDLE", "OFF", "DOWN"]

    /// `states` are in the order IOReport lists them. After dropping inactive states, the
    /// nth active state runs at `table[n]`. States beyond the table are ignored.
    static func averageFrequency(states: [(name: String, residency: Int64)], table: [Frequency]) -> Frequency? {
        let active = states.filter { !inactiveStates.contains($0.name) }
        var weighted = 0.0
        var total = 0.0
        for (index, state) in active.enumerated() where index < table.count && state.residency > 0 {
            weighted += Double(state.residency) * table[index].hertz
            total += Double(state.residency)
        }
        guard total > 0 else { return nil }
        return Frequency(hertz: weighted / total)
    }

    /// Frequencies from a device tree `voltage-states` property: little-endian
    /// (frequency, voltage) UInt32 pairs. Zero-frequency (off) entries are dropped.
    /// Units vary by chip generation, so values are normalized to hertz by magnitude.
    static func frequencyTable(fromVoltageStates data: [UInt8]) -> [Frequency] {
        let words = stride(from: 0, to: data.count - 3, by: 4).map { offset in
            UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
        }
        return stride(from: 0, to: words.count, by: 2).compactMap { index in
            let value = Double(words[index])
            switch value {
            case 0: return nil
            case 10_000_000...: return Frequency(hertz: value)
            case 10_000...: return Frequency(hertz: value * 1_000)
            default: return Frequency(megahertz: value)
            }
        }
    }
}
