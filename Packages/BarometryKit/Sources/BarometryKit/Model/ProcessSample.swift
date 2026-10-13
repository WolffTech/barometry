import Foundation

/// Processor time as a share of one core, like Activity Monitor's "% CPU". Unlike `Percent`,
/// it passes 100% when a process keeps more than one core busy.
public struct CPUUsage: Hashable, Comparable, Sendable {
    public let cores: Double

    public init(cores: Double) {
        self.cores = cores.isFinite ? max(cores, 0) : 0
    }

    public static func < (lhs: CPUUsage, rhs: CPUUsage) -> Bool {
        lhs.cores < rhs.cores
    }

    /// One decimal, as Activity Monitor shows it, such as "6.1%" or "143.0%".
    public func formatted(locale: Locale = .autoupdatingCurrent) -> String {
        cores.formatted(.percent.precision(.fractionLength(1)).locale(locale))
    }
}

/// One process's resource use over the last interval.
public struct ProcessUsage: Equatable, Sendable, Identifiable {
    public let id: Int32
    public internal(set) var name: String
    public let cpu: CPUUsage
    /// Physical footprint, as Activity Monitor's "Memory" column.
    public let memory: ByteCount
    public let power: Power

    public init(id: Int32, name: String, cpu: CPUUsage, memory: ByteCount, power: Power) {
        self.id = id
        self.name = name
        self.cpu = cpu
        self.memory = memory
        self.power = power
    }
}

/// The busiest processes by each measure. Only the user's own processes are included,
/// since reading other users' needs root.
public struct TopProcesses: Equatable, Sendable {
    public let byCPU: [ProcessUsage]
    public let byMemory: [ProcessUsage]
    public let byPower: [ProcessUsage]

    public init(byCPU: [ProcessUsage], byMemory: [ProcessUsage], byPower: [ProcessUsage]) {
        self.byCPU = byCPU
        self.byMemory = byMemory
        self.byPower = byPower
    }
}

/// Cumulative counters for one process from `proc_pid_rusage`.
struct ProcessReading: Equatable {
    let pid: Int32
    /// Tells a reused process ID apart from the process that had it before.
    let startTime: UInt64
    /// User and system time, in nanoseconds.
    let cpuTime: UInt64
    /// Energy used, in nanojoules.
    let energy: UInt64
    let memory: UInt64
}

/// Turns successive readings of every process into the busiest few.
struct ProcessUsageTracker {
    /// Processes in each list.
    static let count = 4
    /// Shortest span worth measuring. A tick that lands just after the first reading would
    /// otherwise rank processes by a few milliseconds of noise.
    static let minimumInterval = Duration.milliseconds(500)

    private var previous: (readings: [Int32: ProcessReading], time: ContinuousClock.Instant)?

    /// Returns nil for the first readings, since usage needs two, and for readings too soon
    /// after the last, which are dropped. Only processes present in both readings are ranked.
    /// `name` is called only for the processes that make a list.
    mutating func update(
        _ readings: [ProcessReading],
        at time: ContinuousClock.Instant,
        name: (Int32) -> String
    ) -> TopProcesses? {
        if let previous, time - previous.time < Self.minimumInterval {
            return nil
        }
        let earlier = previous
        previous = (Dictionary(readings.map { ($0.pid, $0) }, uniquingKeysWith: { $1 }), time)
        guard let earlier else { return nil }
        let elapsed = (time - earlier.time).seconds

        // Named later, since looking up a name costs more than reading a process.
        let measured = readings.compactMap { reading -> ProcessUsage? in
            guard let before = earlier.readings[reading.pid], before.startTime == reading.startTime else { return nil }
            return ProcessUsage(
                id: reading.pid,
                name: "",
                cpu: CPUUsage(cores: Double(reading.cpuTime &- before.cpuTime) / 1e9 / elapsed),
                memory: ByteCount(bytes: Int64(clamping: reading.memory)),
                power: Power(watts: Double(reading.energy &- before.energy) / 1e9 / elapsed)
            )
        }
        var names: [Int32: String] = [:]
        func top<Value: Comparable>(by value: (ProcessUsage) -> Value) -> [ProcessUsage] {
            measured.sorted { value($0) > value($1) }.prefix(Self.count).map { usage in
                var named = usage
                named.name = names[usage.id] ?? name(usage.id)
                names[usage.id] = named.name
                return named
            }
        }
        return TopProcesses(byCPU: top(by: \.cpu), byMemory: top(by: \.memory), byPower: top(by: \.power))
    }

    mutating func reset() {
        previous = nil
    }
}
