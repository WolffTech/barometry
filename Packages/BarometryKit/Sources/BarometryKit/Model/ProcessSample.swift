// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

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

/// The app a group of processes belongs to.
public struct AppIdentity: Equatable, Sendable {
    public let name: String
    /// The app bundle, for its icon. Nil for processes outside an app, such as command-line tools.
    public let bundleURL: URL?

    public init(name: String, bundleURL: URL?) {
        self.name = name
        self.bundleURL = bundleURL
    }

    /// The outermost app bundle in the path, so helpers nested inside an app, such as
    /// "Google Chrome Helper (Renderer).app", name the app itself. Otherwise the file name.
    init(executablePath path: String) {
        let url = URL(filePath: path)
        let components = url.pathComponents
        if let index = components.firstIndex(where: { $0.hasSuffix(".app") }) {
            let bundle = URL(filePath: NSString.path(withComponents: Array(components[...index])), directoryHint: .isDirectory)
            self.init(name: bundle.deletingPathExtension().lastPathComponent, bundleURL: bundle)
        } else {
            self.init(name: url.lastPathComponent, bundleURL: nil)
        }
    }
}

/// One app's resource use over the last interval, summed over every process macOS holds it
/// responsible for. That includes helpers outside its bundle, such as Safari's
/// WebContent processes, and command-line tools started from it, as Activity Monitor's
/// Energy tab counts them.
public struct AppUsage: Equatable, Sendable, Identifiable {
    /// The responsible process's ID.
    public let id: Int32
    public internal(set) var app: AppIdentity
    public let cpu: CPUUsage
    /// Physical footprint, as Activity Monitor's "Memory" column.
    public let memory: ByteCount
    public let power: Power

    public init(id: Int32, app: AppIdentity, cpu: CPUUsage, memory: ByteCount, power: Power) {
        self.id = id
        self.app = app
        self.cpu = cpu
        self.memory = memory
        self.power = power
    }
}

/// The busiest apps by each measure. Only the user's own processes are included,
/// since reading other users' needs root.
public struct TopApps: Equatable, Sendable {
    public let byCPU: [AppUsage]
    public let byMemory: [AppUsage]
    public let byPower: [AppUsage]

    public init(byCPU: [AppUsage], byMemory: [AppUsage], byPower: [AppUsage]) {
        self.byCPU = byCPU
        self.byMemory = byMemory
        self.byPower = byPower
    }
}

/// Cumulative counters for one process from `proc_pid_rusage`.
struct ProcessReading: Equatable {
    let pid: Int32
    /// The process macOS holds responsible for this one, which may be itself.
    let owner: Int32
    /// Tells a reused process ID apart from the process that had it before.
    let startTime: UInt64
    /// User and system time, in nanoseconds.
    let cpuTime: UInt64
    /// Energy used, in nanojoules.
    let energy: UInt64
    let memory: UInt64
}

/// Turns successive readings of every process into the busiest few apps.
struct ProcessUsageTracker {
    /// Apps in each list.
    static let count = 4
    /// Shortest span worth measuring. A tick that lands just after the first reading would
    /// otherwise rank processes by a few milliseconds of noise.
    static let minimumInterval = Duration.milliseconds(500)

    private var previous: (readings: [Int32: ProcessReading], time: ContinuousClock.Instant)?

    /// Returns nil for the first readings, since usage needs two, and for readings too soon
    /// after the last, which are dropped. Only processes present in both readings count.
    /// `identify` is called only for the apps that make a list, with the responsible process
    /// and one of its processes to fall back on if the responsible one has exited.
    mutating func update(
        _ readings: [ProcessReading],
        at time: ContinuousClock.Instant,
        identify: (_ owner: Int32, _ member: Int32) -> AppIdentity
    ) -> TopApps? {
        if let previous, time - previous.time < Self.minimumInterval {
            return nil
        }
        let earlier = previous
        previous = (Dictionary(readings.map { ($0.pid, $0) }, uniquingKeysWith: { $1 }), time)
        guard let earlier else { return nil }
        let elapsed = (time - earlier.time).seconds

        var totals: [Int32: Totals] = [:]
        for reading in readings {
            guard let before = earlier.readings[reading.pid], before.startTime == reading.startTime else { continue }
            totals[reading.owner, default: Totals(member: reading.pid)].add(reading, since: before)
        }
        // Identified later, since looking up an app costs more than reading a process.
        let measured = totals.map { owner, total in
            AppUsage(
                id: owner,
                app: AppIdentity(name: "", bundleURL: nil),
                cpu: CPUUsage(cores: Double(total.cpuTime) / 1e9 / elapsed),
                memory: ByteCount(bytes: Int64(clamping: total.memory)),
                power: Power(watts: Double(total.energy) / 1e9 / elapsed)
            )
        }
        var apps: [Int32: AppIdentity] = [:]
        func top<Value: Comparable>(by value: (AppUsage) -> Value) -> [AppUsage] {
            measured.sorted { value($0) > value($1) }.prefix(Self.count).map { usage in
                var identified = usage
                identified.app = apps[usage.id] ?? identify(usage.id, totals[usage.id]!.member)
                apps[usage.id] = identified.app
                return identified
            }
        }
        return TopApps(byCPU: top(by: \.cpu), byMemory: top(by: \.memory), byPower: top(by: \.power))
    }

    mutating func reset() {
        previous = nil
    }

    /// One app's usage since the earlier readings.
    private struct Totals {
        let member: Int32
        var cpuTime: UInt64 = 0
        var energy: UInt64 = 0
        var memory: UInt64 = 0

        mutating func add(_ reading: ProcessReading, since before: ProcessReading) {
            cpuTime &+= reading.cpuTime &- before.cpuTime
            energy &+= reading.energy &- before.energy
            memory &+= reading.memory
        }
    }
}
