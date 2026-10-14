// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

public enum CoreKind: Sendable {
    case efficiency
    case performance
}

/// Cumulative scheduler ticks for one logical CPU since boot.
/// The kernel reports these as 32-bit counters that wrap.
public struct CPUTicks: Equatable, Sendable {
    public var user: UInt32
    public var system: UInt32
    public var idle: UInt32
    public var nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

/// Ticks spent in each state over an interval.
struct TickDelta {
    var user: UInt64 = 0
    var system: UInt64 = 0
    var idle: UInt64 = 0

    /// Wrapping subtraction keeps the delta correct across one counter wrap.
    init(from old: CPUTicks, to new: CPUTicks) {
        user = UInt64(new.user &- old.user) + UInt64(new.nice &- old.nice)
        system = UInt64(new.system &- old.system)
        idle = UInt64(new.idle &- old.idle)
    }

    init() {}

    static func + (lhs: TickDelta, rhs: TickDelta) -> TickDelta {
        var sum = TickDelta()
        sum.user = lhs.user + rhs.user
        sum.system = lhs.system + rhs.system
        sum.idle = lhs.idle + rhs.idle
        return sum
    }
}

public struct CPULoad: Equatable, Sendable {
    /// User time, including low-priority (nice) work.
    public let user: Percent
    public let system: Percent

    public init(user: Percent, system: Percent) {
        self.user = user
        self.system = system
    }

    public static let idle = CPULoad(user: .zero, system: .zero)

    public var total: Percent {
        Percent(user.fraction + system.fraction)
    }

    init(_ delta: TickDelta) {
        let total = Double(delta.user + delta.system + delta.idle)
        self.init(user: Percent(Double(delta.user), of: total), system: Percent(Double(delta.system), of: total))
    }
}

public struct CoreLoad: Equatable, Sendable, Identifiable {
    /// Logical CPU number.
    public let id: Int
    public let kind: CoreKind
    public let load: CPULoad

    public init(id: Int, kind: CoreKind, load: CPULoad) {
        self.id = id
        self.kind = kind
        self.load = load
    }
}

public struct CPUSample: Equatable, Sendable {
    /// Load across all cores, weighted by ticks.
    public let total: CPULoad
    /// Per-core load, ordered by logical CPU number.
    public let cores: [CoreLoad]

    public init(total: CPULoad, cores: [CoreLoad]) {
        self.total = total
        self.cores = cores
    }

    /// Load between two readings. Returns nil if the core count changed between them.
    /// `kinds` is indexed by logical CPU; cores it doesn't cover count as performance cores.
    init?(from old: [CPUTicks], to new: [CPUTicks], kinds: [CoreKind]) {
        guard !new.isEmpty, old.count == new.count else { return nil }
        let deltas = zip(old, new).map(TickDelta.init(from:to:))
        total = CPULoad(deltas.reduce(TickDelta(), +))
        cores = deltas.enumerated().map { id, delta in
            CoreLoad(id: id, kind: kinds.indices.contains(id) ? kinds[id] : .performance, load: CPULoad(delta))
        }
    }

    /// Mean total load of one core kind, or nil if the machine has none.
    public func averageLoad(of kind: CoreKind) -> Percent? {
        let matching = cores.filter { $0.kind == kind }
        guard !matching.isEmpty else { return nil }
        return Percent(matching.map(\.load.total.fraction).reduce(0, +) / Double(matching.count))
    }
}
