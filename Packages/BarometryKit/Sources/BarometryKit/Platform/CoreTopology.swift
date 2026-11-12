// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import IOKit

struct CoreTopology: Equatable {
    struct PerfLevel: Equatable {
        let kind: CoreKind
        let logicalCPUs: Int
    }

    struct CPUNode: Equatable {
        let logicalID: Int
        let clusterID: Int?
        let clusterType: Character
    }

    struct Cluster: Equatable {
        let id: Int
        let type: Character
        let kind: CoreKind
    }

    /// Core kinds indexed by logical CPU number.
    let kinds: [CoreKind]
    let clusters: [Cluster]

    static func current() -> CoreTopology {
        let levels = perfLevels()
        if let cpus = deviceTreeCPUs(), let topology = CoreTopology(cpus: cpus, levels: levels) {
            return topology
        }
        return CoreTopology(levels: levels)
    }

    /// Apple Silicon numbers its slowest cores first.
    init(levels: [PerfLevel]) {
        kinds = levels.reversed().flatMap { Array(repeating: $0.kind, count: max($0.logicalCPUs, 0)) }
        clusters = []
    }

    init?(cpus: [CPUNode], levels: [PerfLevel]) {
        let clusterTypesSlowestFirst: [Character] = ["E", "M", "P"]
        let types = Set(cpus.map(\.clusterType))
        guard !cpus.isEmpty,
              types.isSubset(of: clusterTypesSlowestFirst),
              types.count == levels.count,
              Set(cpus.map(\.logicalID)) == Set(0..<cpus.count)
        else { return nil }

        let presentTypes = clusterTypesSlowestFirst.filter(types.contains)
        let kindByType = Dictionary(uniqueKeysWithValues: zip(presentTypes, levels.reversed().map(\.kind)))
        let byLogicalID = Dictionary(uniqueKeysWithValues: cpus.map { ($0.logicalID, $0) })
        kinds = (0..<cpus.count).compactMap { byLogicalID[$0].flatMap { kindByType[$0.clusterType] } }
        let typeByClusterID = Dictionary(cpus.compactMap { cpu in cpu.clusterID.map { ($0, cpu.clusterType) } }) { first, _ in first }
        clusters = typeByClusterID
            .compactMap { id, type in kindByType[type].map { Cluster(id: id, type: type, kind: $0) } }
            .sorted { $0.id < $1.id }
    }

    private static func perfLevels() -> [PerfLevel] {
        let count = Int(Sysctl.integer("hw.nperflevels", as: Int32.self) ?? 0)
        let levels = (0..<count).compactMap { level -> PerfLevel? in
            guard let cpus = Sysctl.integer("hw.perflevel\(level).logicalcpu", as: Int32.self) else { return nil }
            let kind = Sysctl.string("hw.perflevel\(level).name").flatMap(CoreKind.init(perflevelName:))
                ?? (level == 0 ? .performance : .efficiency)
            return PerfLevel(kind: kind, logicalCPUs: Int(cpus))
        }
        if levels.isEmpty, let cpus = Sysctl.integer("hw.ncpu", as: Int32.self) {
            return [PerfLevel(kind: .performance, logicalCPUs: Int(cpus))]
        }
        return levels
    }

    /// Reads each `IODeviceTree:/cpus/cpuN` node's `logical-cpu-id`, `cluster-id`, and `cluster-type`.
    private static func deviceTreeCPUs() -> [CPUNode]? {
        let cpus = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        guard cpus != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(cpus) }

        var iterator = io_iterator_t()
        guard IORegistryEntryGetChildIterator(cpus, kIODeviceTreePlane, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var nodes: [CPUNode] = []
        while case let entry = IOIteratorNext(iterator), entry != IO_OBJECT_NULL {
            defer { IOObjectRelease(entry) }
            guard let id = property(entry, "logical-cpu-id") as? Int,
                  let clusterType = (property(entry, "cluster-type") as? Data)?.first
            else { continue }
            let clusterID = (property(entry, "cluster-id") as? Data)?.first.map(Int.init)
            nodes.append(CPUNode(logicalID: id, clusterID: clusterID, clusterType: Character(UnicodeScalar(clusterType))))
        }
        return nodes.isEmpty ? nil : nodes
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
