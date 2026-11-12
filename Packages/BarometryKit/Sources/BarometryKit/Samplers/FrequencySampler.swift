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
    private struct CoreCluster {
        let kind: CoreKind
        let channelPrefix: String
        let table: [Frequency]
    }

    private static let legacyCoreTableKeys: [Character: String] = ["E": "voltage-states1-sram", "P": "voltage-states5-sram"]

    private let coreClusters: [CoreCluster]
    private let gpuTable: [Frequency]

    init() {
        let pmgr = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("pmgr"))
        defer { IOObjectRelease(pmgr) }
        func data(_ key: String) -> [UInt8]? {
            guard pmgr != IO_OBJECT_NULL,
                  let value = IORegistryEntryCreateCFProperty(pmgr, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data
            else { return nil }
            return Array(value)
        }
        func table(_ key: String) -> [Frequency] {
            data(key).map(DVFS.frequencyTable(fromVoltageStates:)) ?? []
        }

        let clusters = CoreTopology.current().clusters
        let kindByType = clusters.isEmpty
            ? ["E": .efficiency, "P": .performance]
            : Dictionary(clusters.map { ($0.type, $0.kind) }) { first, _ in first }
        let voltageStatesByCluster = data("acc-clusters").map(DVFS.voltageStateIndices(fromAccClusters:)) ?? [:]

        coreClusters = kindByType.sorted { $0.key < $1.key }.map { type, kind in
            let legacyTable = Self.legacyCoreTableKeys[type].map(table) ?? []
            let discoveredTable = clusters.first { $0.type == type }
                .flatMap { voltageStatesByCluster[$0.id] }
                .map { table("voltage-states\($0)-sram") } ?? []
            return CoreCluster(kind: kind, channelPrefix: "\(type)CPU", table: legacyTable.isEmpty ? discoveredTable : legacyTable)
        }
        gpuTable = table("voltage-states9")
    }

    /// Nil on the first call and when IOReport is unavailable.
    func sample() -> FrequencySample? {
        guard let channels = subscription?.sample(), !channels.isEmpty else { return nil }

        // Channel names: ECPU/MCPU/PCPU per cluster (with a trailing number on multi-cluster chips),
        // ECPM/MCPM/PCPM for cluster memory, which is skipped, and GPUPH for the GPU.
        func frequency(prefix: String, table: [Frequency]) -> Frequency? {
            let states = channels
                .filter { $0.name.hasPrefix(prefix) }
                .flatMap(\.states)
            return DVFS.averageFrequency(states: Self.mergeByName(states), table: table)
        }

        let cores = coreClusters.compactMap { cluster in
            frequency(prefix: cluster.channelPrefix, table: cluster.table).map { (cluster.kind, $0) }
        }
        return FrequencySample(
            cores: Dictionary(cores) { first, _ in first },
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

}
