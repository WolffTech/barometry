import IOKit.ps

public struct BatterySample: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Time to full is nil while macOS is still estimating.
        case charging(timeToFull: Duration?)
        case charged
        /// On power but holding charge, such as during Optimized Battery Charging.
        case notCharging
        /// Time remaining is nil while macOS is still estimating.
        case discharging(timeRemaining: Duration?)
    }

    public let charge: Percent
    public let state: State
    /// Nil when it couldn't be read.
    public internal(set) var health: BatteryHealth?

    public init(charge: Percent, state: State, health: BatteryHealth? = nil) {
        self.charge = charge
        self.state = state
        self.health = health
    }

    /// Parses an `IOPSGetPowerSourceDescription` dictionary.
    /// Returns nil for anything other than a present internal battery, such as a UPS.
    init?(powerSourceDescription description: [String: Any]) {
        guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              description[kIOPSIsPresentKey] as? Bool ?? true,
              let current = description[kIOPSCurrentCapacityKey] as? Int,
              let max = description[kIOPSMaxCapacityKey] as? Int
        else { return nil }

        let charge = Percent(Double(current), of: Double(max))
        let onPower = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
        let isCharged = description[kIOPSIsChargedKey] as? Bool ?? false

        // Time estimates are in minutes, with -1 meaning "still calculating".
        func minutes(_ key: String) -> Duration? {
            guard let value = description[key] as? Int, value >= 0 else { return nil }
            return .seconds(value * 60)
        }

        let state: State
        if !onPower {
            state = .discharging(timeRemaining: minutes(kIOPSTimeToEmptyKey))
        } else if isCharging {
            state = .charging(timeToFull: minutes(kIOPSTimeToFullChargeKey))
        } else if isCharged || charge.fraction >= 1 {
            state = .charged
        } else {
            state = .notCharging
        }
        self.init(charge: charge, state: state)
    }
}

public struct BatteryHealth: Equatable, Sendable {
    public let cycleCount: Int
    /// Full-charge capacity relative to when new, like "Maximum Capacity" in System Settings.
    public let maximumCapacity: Percent

    public init(cycleCount: Int, maximumCapacity: Percent) {
        self.cycleCount = cycleCount
        self.maximumCapacity = maximumCapacity
    }

    /// Parses `AppleSmartBattery` registry properties. Newer macOS versions drop the
    /// top-level capacities and keep them only in `BatteryData`.
    init?(registry properties: [String: Any]) {
        let batteryData = properties["BatteryData"] as? [String: Any] ?? [:]
        guard let cycleCount = properties["CycleCount"] as? Int,
              let design = properties["DesignCapacity"] as? Int ?? batteryData["DesignCapacity"] as? Int,
              let full = properties["AppleRawMaxCapacity"] as? Int ?? batteryData["NominalChargeCapacity"] as? Int
        else { return nil }
        self.init(cycleCount: cycleCount, maximumCapacity: Percent(Double(full), of: Double(design)))
    }
}
