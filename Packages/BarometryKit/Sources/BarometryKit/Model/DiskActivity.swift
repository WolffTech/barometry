/// Bytes read from and written to all disks.
public struct DiskActivity: Equatable, Sendable {
    public let read: ByteRate
    public let write: ByteRate

    public init(read: ByteRate, write: ByteRate) {
        self.read = read
        self.write = write
    }
}

/// Cumulative byte counts summed over every disk.
struct DiskCounters: Equatable {
    var read: UInt64
    var written: UInt64
}

/// Turns successive counter readings into rates.
struct DiskActivityTracker {
    private var previous: (counters: DiskCounters, time: ContinuousClock.Instant)?

    /// Returns nil for the first reading, and when a total drops because a disk was ejected.
    mutating func update(_ counters: DiskCounters, at time: ContinuousClock.Instant) -> DiskActivity? {
        defer { previous = (counters, time) }
        guard let previous, counters.read >= previous.counters.read, counters.written >= previous.counters.written else { return nil }
        let elapsed = (time - previous.time).seconds
        guard elapsed > 0 else { return nil }
        return DiskActivity(
            read: ByteRate(bytesPerSecond: Double(counters.read - previous.counters.read) / elapsed),
            write: ByteRate(bytesPerSecond: Double(counters.written - previous.counters.written) / elapsed)
        )
    }
}
