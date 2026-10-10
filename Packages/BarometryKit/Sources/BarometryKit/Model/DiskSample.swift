public struct DiskSample: Equatable, Sendable {
    /// Volume name, such as "Macintosh HD".
    public let name: String
    public let total: ByteCount
    /// Space available for user files, including purgeable space, as Finder reports it.
    public let available: ByteCount

    public init(name: String, total: ByteCount, available: ByteCount) {
        self.name = name
        self.total = total
        self.available = available
    }

    public var usage: Percent {
        Percent(Double(total.bytes - available.bytes), of: Double(total.bytes))
    }
}
