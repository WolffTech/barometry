// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Darwin

enum Sysctl {
    /// Reads a fixed-size integer sysctl, or nil if it doesn't exist or has a different size.
    static func integer<Value: FixedWidthInteger>(_ name: String, as type: Value.Type = Value.self) -> Value? {
        var value = Value.zero
        var size = MemoryLayout<Value>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0, size == MemoryLayout<Value>.size else { return nil }
        return value
    }

    /// Reads a sysctl holding a C struct, such as `xsw_usage`, or nil if it doesn't exist or has a different size.
    static func value<Value: BitwiseCopyable>(_ name: String, empty: Value) -> Value? {
        var value = empty
        var size = MemoryLayout<Value>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0, size == MemoryLayout<Value>.size else { return nil }
        return value
    }

    /// Reads a string sysctl, or nil if it doesn't exist.
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
