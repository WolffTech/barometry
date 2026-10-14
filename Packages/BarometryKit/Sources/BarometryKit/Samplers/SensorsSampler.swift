// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

/// Reads temperatures, system power, and fans from the SMC.
struct SensorsSampler {
    /// Each SMC read costs about 0.2 ms and an M3 Pro has ~80 die sensors, so each tick
    /// reads only this fraction of them and averages the latest value of every sensor.
    private static let temperatureBatches = 4

    private let smc: SMC?
    private let cpuTemperatureKeys: [String]
    private let gpuTemperatureKeys: [String]
    private let fanCount: Int
    private var latestTemperatures: [String: Double] = [:]
    private var nextBatch = 0

    init() {
        smc = SMC()
        // Apple Silicon names CPU die sensors Tp*/Te* (performance/efficiency) and GPU
        // sensors Tg*. The exact keys differ per chip, so match by prefix once at startup.
        let floatKeys = smc.map { smc in smc.allKeys().filter { $0.hasPrefix("T") && smc.dataType($0) == "flt " } } ?? []
        cpuTemperatureKeys = floatKeys.filter { $0.hasPrefix("Tp") || $0.hasPrefix("Te") }
        gpuTemperatureKeys = floatKeys.filter { $0.hasPrefix("Tg") }
        fanCount = smc?.number("FNum").map { Int($0) } ?? 0
        if let smc {
            for key in cpuTemperatureKeys + gpuTemperatureKeys {
                latestTemperatures[key] = smc.number(key)
            }
        }
    }

    /// Nil when the SMC can't be opened.
    mutating func sample() -> SensorSample? {
        guard let smc else { return nil }
        let keys = cpuTemperatureKeys + gpuTemperatureKeys
        for (offset, key) in keys.enumerated() where offset % Self.temperatureBatches == nextBatch {
            latestTemperatures[key] = smc.number(key)
        }
        nextBatch = (nextBatch + 1) % Self.temperatureBatches
        return SensorSample(
            cpuTemperature: SensorSample.meanTemperature(cpuTemperatureKeys.compactMap { latestTemperatures[$0] }),
            gpuTemperature: SensorSample.meanTemperature(gpuTemperatureKeys.compactMap { latestTemperatures[$0] }),
            systemPower: smc.number("PSTR").map(Power.init(watts:)),
            fans: (0..<fanCount).compactMap { index in
                smc.number("F\(index)Ac").map { rpm in
                    Fan(id: index, rpm: rpm, maximumRPM: smc.number("F\(index)Mx"))
                }
            }
        )
    }
}
