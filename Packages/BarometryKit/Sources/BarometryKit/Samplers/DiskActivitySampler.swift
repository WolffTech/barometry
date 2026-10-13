import Foundation
import IOKit

/// Reads transfer totals from each block storage driver's `Statistics`.
struct DiskActivitySampler {
    private var tracker = DiskActivityTracker()

    /// Returns nil on the first call, since rates need two readings.
    mutating func sample() -> DiskActivity? {
        Self.counters().flatMap { tracker.update($0, at: .now) }
    }

    private static func counters() -> DiskCounters? {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var total = DiskCounters(read: 0, written: 0)
        while case let driver = IOIteratorNext(iterator), driver != IO_OBJECT_NULL {
            defer { IOObjectRelease(driver) }
            guard let statistics = IORegistryEntryCreateCFProperty(driver, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any]
            else { continue }
            total.read += (statistics["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            total.written += (statistics["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
        }
        return total
    }
}
