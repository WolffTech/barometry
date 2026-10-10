import Foundation
import IOKit

enum CoreTopology {
    /// Core kinds indexed by logical CPU number.
    static func current() -> [CoreKind] {
        if let kinds = deviceTreeKinds() {
            return kinds
        }
        let performance = Sysctl.integer("hw.perflevel0.logicalcpu", as: Int32.self)
            ?? Sysctl.integer("hw.ncpu", as: Int32.self)
            ?? 0
        let efficiency = Sysctl.integer("hw.perflevel1.logicalcpu", as: Int32.self) ?? 0
        return fallbackKinds(efficiency: Int(efficiency), performance: Int(performance))
    }

    /// Apple Silicon numbers efficiency cores before performance cores.
    static func fallbackKinds(efficiency: Int, performance: Int) -> [CoreKind] {
        Array(repeating: .efficiency, count: max(efficiency, 0)) + Array(repeating: .performance, count: max(performance, 0))
    }

    /// Reads each `IODeviceTree:/cpus/cpuN` node's `logical-cpu-id` and `cluster-type` ("E" or "P").
    private static func deviceTreeKinds() -> [CoreKind]? {
        let cpus = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        guard cpus != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(cpus) }

        var iterator = io_iterator_t()
        guard IORegistryEntryGetChildIterator(cpus, kIODeviceTreePlane, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var kindsByID: [Int: CoreKind] = [:]
        while case let entry = IOIteratorNext(iterator), entry != IO_OBJECT_NULL {
            defer { IOObjectRelease(entry) }
            guard let id = property(entry, "logical-cpu-id") as? Int,
                  let clusterType = property(entry, "cluster-type") as? Data,
                  let first = clusterType.first
            else { continue }
            kindsByID[id] = first == UInt8(ascii: "E") ? .efficiency : .performance
        }

        guard !kindsByID.isEmpty, Set(kindsByID.keys) == Set(0..<kindsByID.count) else { return nil }
        return (0..<kindsByID.count).compactMap { kindsByID[$0] }
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
