// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import IOKit

/// Average CPU cluster and GPU clocks, from IOReport state residency and the
/// frequency tables in the device tree's power manager node.
struct FrequencySampler {
    private let subscription = IOReportSubscription(channels: [
        ("CPU Stats", "CPU Complex Performance States"),
        ("GPU Stats", "GPU Performance States"),
    ])
    private let efficiencyTable: [Frequency]
    private let performanceTable: [Frequency]
    private let gpuTable: [Frequency]

    init() {
        let tables = Self.voltageStateTables(["voltage-states1-sram", "voltage-states5-sram", "voltage-states9"])
        efficiencyTable = tables[0]
        performanceTable = tables[1]
        gpuTable = tables[2]
    }

    /// Nil on the first call and when IOReport is unavailable.
    func sample() -> FrequencySample? {
        guard let channels = subscription?.sample(), !channels.isEmpty else { return nil }

        // Channel names: ECPU/PCPU per cluster (with a trailing number on multi-cluster chips),
        // ECPM/PCPM for cluster memory, which is skipped, and GPUPH for the GPU.
        func frequency(prefix: String, table: [Frequency]) -> Frequency? {
            let states = channels
                .filter { $0.name.hasPrefix(prefix) }
                .flatMap(\.states)
            return DVFS.averageFrequency(states: Self.mergeByName(states), table: table)
        }

        return FrequencySample(
            efficiencyCores: frequency(prefix: "ECPU", table: efficiencyTable),
            performanceCores: frequency(prefix: "PCPU", table: performanceTable),
            gpu: frequency(prefix: "GPUPH", table: gpuTable),
            gpuMaximum: gpuTable.max()
        )
    }

    /// Sums residency for same-named states across clusters, keeping first-seen order.
    private static func mergeByName(_ states: [(name: String, residency: Int64)]) -> [(name: String, residency: Int64)] {
        var order: [String] = []
        var totals: [String: Int64] = [:]
        for state in states {
            if totals[state.name] == nil {
                order.append(state.name)
            }
            totals[state.name, default: 0] += state.residency
        }
        return order.map { ($0, totals[$0] ?? 0) }
    }

    private static func voltageStateTables(_ keys: [String]) -> [[Frequency]] {
        let pmgr = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("pmgr"))
        guard pmgr != IO_OBJECT_NULL else { return keys.map { _ in [] } }
        defer { IOObjectRelease(pmgr) }
        return keys.map { key in
            guard let data = IORegistryEntryCreateCFProperty(pmgr, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data else { return [] }
            return DVFS.frequencyTable(fromVoltageStates: Array(data))
        }
    }
}
