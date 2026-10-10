public struct MemoryPressure: Equatable, Sendable {
    public enum Level: Sendable {
        case normal
        case warning
        case critical

        /// Maps `kern.memorystatus_vm_pressure_level` (1, 2, 4) to a level.
        init(kernelValue: Int32) {
            switch kernelValue {
            case 4: self = .critical
            case 2: self = .warning
            default: self = .normal
            }
        }
    }

    public let level: Level
    public let percent: Percent

    public init(level: Level, percent: Percent) {
        self.level = level
        self.percent = percent
    }

    /// `availableLevel` is `kern.memorystatus_level`, the percentage of memory still
    /// available; pressure is its complement.
    init(kernelLevel: Int32, availableLevel: Int32) {
        self.init(level: Level(kernelValue: kernelLevel), percent: Percent(Double(100 - availableLevel) / 100))
    }
}

/// Page counts from `host_statistics64(HOST_VM_INFO64)`.
struct VMPageCounts {
    var `internal`: UInt64
    var purgeable: UInt64
    var external: UInt64
    var wired: UInt64
    var compressor: UInt64
}

public struct MemorySample: Equatable, Sendable {
    public let total: ByteCount
    /// Anonymous memory owned by processes.
    public let app: ByteCount
    public let wired: ByteCount
    public let compressed: ByteCount
    /// File-backed and purgeable memory the system can reclaim.
    public let cached: ByteCount
    public let pressure: MemoryPressure

    public init(total: ByteCount, app: ByteCount, wired: ByteCount, compressed: ByteCount, cached: ByteCount, pressure: MemoryPressure) {
        self.total = total
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
        self.pressure = pressure
    }

    /// Matches Activity Monitor's "Memory Used".
    public var used: ByteCount {
        app + wired + compressed
    }

    public var usage: Percent {
        Percent(Double(used.bytes), of: Double(total.bytes))
    }

    /// Breaks page counts down the same way Activity Monitor does.
    init(pages: VMPageCounts, pageSize: UInt64, total: ByteCount, pressure: MemoryPressure) {
        func bytes(_ pageCount: UInt64) -> ByteCount {
            ByteCount(bytes: Int64(clamping: pageCount * pageSize))
        }
        let appPages = pages.internal > pages.purgeable ? pages.internal - pages.purgeable : 0
        self.init(
            total: total,
            app: bytes(appPages),
            wired: bytes(pages.wired),
            compressed: bytes(pages.compressor),
            cached: bytes(pages.external + pages.purgeable),
            pressure: pressure
        )
    }
}
