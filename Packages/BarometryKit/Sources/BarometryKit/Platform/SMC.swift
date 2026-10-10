import IOKit

/// Read-only client for the System Management Controller, which exposes temperatures,
/// fan speeds, and power readings as four-character keys. Undocumented; key names vary by chip.
final class SMC {
    struct KeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var attributes: UInt8 = 0
    }

    private let connection: io_connect_t
    private var keyInfoCache: [UInt32: KeyInfo] = [:]

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        var connection = io_connect_t()
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else { return nil }
        self.connection = connection
    }

    deinit {
        IOServiceClose(connection)
    }

    /// Every key the SMC reports. Enumerating takes a few thousand calls, so do it once.
    func allKeys() -> [String] {
        guard let count = read("#KEY").flatMap(Self.decodeInteger) else { return [] }
        return (0..<UInt32(count)).compactMap { index in
            var input = Param()
            input.command = Command.keyAtIndex.rawValue
            input.data32 = index
            return call(&input).map { Self.string(fromFourCC: $0.key) }
        }
    }

    /// Reads a key as a number, decoding the SMC's numeric data types.
    func number(_ key: String) -> Double? {
        let code = Self.fourCC(key)
        guard let info = info(code), let bytes = read(code, info: info) else { return nil }
        return Self.decode(bytes, type: Self.string(fromFourCC: info.dataType))
    }

    func dataType(_ key: String) -> String? {
        info(Self.fourCC(key)).map { Self.string(fromFourCC: $0.dataType) }
    }

    // MARK: Decoding

    static func decode(_ bytes: [UInt8], type: String) -> Double? {
        switch type {
        case "flt " where bytes.count >= 4:
            // Apple Silicon floats are little-endian.
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: bits))
        case "ui8 ", "ui16", "ui32":
            return decodeInteger(bytes).map { Double($0) }
        case "sp78" where bytes.count >= 2:
            // Signed 7.8 fixed point, big-endian.
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        case "fpe2" where bytes.count >= 2:
            // Unsigned 14.2 fixed point, big-endian.
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        default:
            return nil
        }
    }

    /// Big-endian unsigned integer.
    static func decodeInteger(_ bytes: [UInt8]) -> UInt64? {
        guard !bytes.isEmpty, bytes.count <= 8 else { return nil }
        return bytes.reduce(0) { $0 << 8 | UInt64($1) }
    }

    static func fourCC(_ key: String) -> UInt32 {
        key.utf8.prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func string(fromFourCC code: UInt32) -> String {
        String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }, as: UTF8.self)
    }

    // MARK: Driver calls

    private enum Command: UInt8 {
        case readKey = 5
        case keyAtIndex = 8
        case keyInfo = 9
    }

    /// Mirrors the driver's `SMCKeyData_t` (80 bytes). Explicit padding keeps Swift from
    /// packing later fields into `KeyInfo`'s tail padding, which C doesn't do.
    private struct Param {
        var key: UInt32 = 0
        var version: (UInt8, UInt8, UInt8, UInt8, UInt16) = (0, 0, 0, 0, 0)
        var powerLimits: (UInt16, UInt16, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0)
        var keyInfo = KeyInfo()
        var keyInfoPadding: (UInt8, UInt8, UInt8) = (0, 0, 0)
        var result: UInt8 = 0
        var status: UInt8 = 0
        var command: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
    }

    private func info(_ key: UInt32) -> KeyInfo? {
        if let cached = keyInfoCache[key] {
            return cached
        }
        var input = Param()
        input.key = key
        input.command = Command.keyInfo.rawValue
        guard let info = call(&input)?.keyInfo else { return nil }
        keyInfoCache[key] = info
        return info
    }

    private func read(_ key: String) -> [UInt8]? {
        let code = Self.fourCC(key)
        return info(code).flatMap { read(code, info: $0) }
    }

    private func read(_ key: UInt32, info: KeyInfo) -> [UInt8]? {
        var input = Param()
        input.key = key
        input.keyInfo.dataSize = info.dataSize
        input.command = Command.readKey.rawValue
        guard let output = call(&input) else { return nil }
        return withUnsafeBytes(of: output.bytes) { Array($0.prefix(min(Int(info.dataSize), 32))) }
    }

    private func call(_ input: inout Param) -> Param? {
        assert(MemoryLayout<Param>.stride == 80, "SMC parameter struct must match the driver's layout")
        var output = Param()
        var outputSize = MemoryLayout<Param>.stride
        let result = IOConnectCallStructMethod(connection, 2, &input, MemoryLayout<Param>.stride, &output, &outputSize)
        return result == KERN_SUCCESS && output.result == 0 ? output : nil
    }
}
