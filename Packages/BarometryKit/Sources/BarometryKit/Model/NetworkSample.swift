/// Cumulative byte counters for one interface. `if_data` reports these as 32-bit
/// values that wrap after 4 GB.
public struct NetworkCounters: Equatable, Sendable {
    public var received: UInt32
    public var sent: UInt32

    public init(received: UInt32, sent: UInt32) {
        self.received = received
        self.sent = sent
    }
}

public struct NetworkSample: Equatable, Sendable {
    /// BSD interface name, such as "en0".
    public let interface: String
    public let upload: ByteRate
    public let download: ByteRate

    public init(interface: String, upload: ByteRate, download: ByteRate) {
        self.interface = interface
        self.upload = upload
        self.download = download
    }
}

/// Turns successive counter readings into rates.
struct NetworkRateTracker {
    private var previous: (interface: String, counters: NetworkCounters, time: ContinuousClock.Instant)?

    /// Returns nil for the first reading, and after the primary interface changes,
    /// because counters from different interfaces can't be compared.
    mutating func update(interface: String, counters: NetworkCounters, at time: ContinuousClock.Instant) -> NetworkSample? {
        defer { previous = (interface, counters, time) }
        guard let previous, previous.interface == interface else { return nil }
        let elapsed = (time - previous.time).seconds
        guard elapsed > 0 else { return nil }
        return NetworkSample(
            interface: interface,
            upload: ByteRate(bytesPerSecond: Double(counters.sent &- previous.counters.sent) / elapsed),
            download: ByteRate(bytesPerSecond: Double(counters.received &- previous.counters.received) / elapsed)
        )
    }

    mutating func reset() {
        previous = nil
    }
}
