import Darwin

enum Sysctl {
    /// Reads a fixed-size integer sysctl, or nil if it doesn't exist or has a different size.
    static func integer<Value: FixedWidthInteger>(_ name: String, as type: Value.Type = Value.self) -> Value? {
        var value = Value.zero
        var size = MemoryLayout<Value>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0, size == MemoryLayout<Value>.size else { return nil }
        return value
    }
}
