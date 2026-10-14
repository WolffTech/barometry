// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// A fraction in 0...1. Out-of-range or non-finite input is clamped so a bad reading
/// can't produce a negative gauge or one past 100%.
public struct Percent: Hashable, Comparable, Sendable {
    public let fraction: Double

    public init(_ fraction: Double) {
        self.fraction = fraction.isFinite ? min(max(fraction, 0), 1) : 0
    }

    /// `part / total`, or zero when `total` is zero.
    public init(_ part: Double, of total: Double) {
        self.init(total > 0 ? part / total : 0)
    }

    public static let zero = Percent(0)

    public static func < (lhs: Percent, rhs: Percent) -> Bool {
        lhs.fraction < rhs.fraction
    }

    /// Whole-number percentage, such as "46%".
    public func formatted(locale: Locale = .autoupdatingCurrent) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}

public struct ByteCount: Hashable, Comparable, Sendable {
    public let bytes: Int64

    public init(bytes: Int64) {
        self.bytes = bytes
    }

    public static let zero = ByteCount(bytes: 0)

    public static func + (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        ByteCount(bytes: lhs.bytes + rhs.bytes)
    }

    public static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.bytes < rhs.bytes
    }

    /// Use `.file` (decimal) for storage, as Finder does, and `.memory` (binary) for RAM,
    /// as Activity Monitor does.
    public func formatted(_ style: ByteCountFormatStyle.Style, locale: Locale = .autoupdatingCurrent) -> String {
        bytes.formatted(.byteCount(style: style).locale(locale))
    }
}

extension ByteCount {
    /// Short binary-unit size for tight spaces: whole MB below 1 GB, otherwise GB with
    /// one decimal, such as "830 MB" or "1.2 GB".
    public func formattedCompact(locale: Locale = .autoupdatingCurrent) -> String {
        let gibibyte = 1_073_741_824.0
        let value = Double(bytes)
        if value < gibibyte {
            return (value / 1_048_576).formatted(.number.precision(.fractionLength(0)).locale(locale)) + " MB"
        }
        return (value / gibibyte).formatted(.number.precision(.fractionLength(1)).locale(locale)) + " GB"
    }
}

public struct ByteRate: Hashable, Comparable, Sendable {
    public let bytesPerSecond: Double

    public init(bytesPerSecond: Double) {
        self.bytesPerSecond = max(bytesPerSecond, 0)
    }

    public static let zero = ByteRate(bytesPerSecond: 0)

    public static func < (lhs: ByteRate, rhs: ByteRate) -> Bool {
        lhs.bytesPerSecond < rhs.bytesPerSecond
    }

    /// Compact rate that never drops below kilobytes, such as "0 KB/s" or "1.5 MB/s",
    /// so menu bar text doesn't jump between units at idle.
    /// Uses decimal units; MB and larger show one fractional digit below 10.
    /// Foundation's byte count style isn't used because it falls back to bytes and prints "kB".
    public func formatted(locale: Locale = .autoupdatingCurrent) -> String {
        let units = ["KB", "MB", "GB", "TB"]
        var value = bytesPerSecond / 1000
        var unit = 0
        while value.rounded() >= 1000, unit < units.count - 1 {
            value /= 1000
            unit += 1
        }
        let fractionDigits = unit > 0 && value < 10 ? 1 : 0
        let number = value.formatted(.number.precision(.fractionLength(0...fractionDigits)).locale(locale))
        return "\(number) \(units[unit])/s"
    }
}

extension Duration {
    var seconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
