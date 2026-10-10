import Foundation

public struct Temperature: Hashable, Comparable, Sendable {
    public let celsius: Double

    public init(celsius: Double) {
        self.celsius = celsius
    }

    public static func < (lhs: Temperature, rhs: Temperature) -> Bool {
        lhs.celsius < rhs.celsius
    }

    /// Whole degrees with a bare degree sign, such as "44°".
    public func formatted(in unit: UnitTemperature = .celsius) -> String {
        let value = Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: unit).value
        return "\(Int(value.rounded()))°"
    }
}

public struct Power: Hashable, Comparable, Sendable {
    public let watts: Double

    public init(watts: Double) {
        self.watts = max(watts, 0)
    }

    public static func < (lhs: Power, rhs: Power) -> Bool {
        lhs.watts < rhs.watts
    }

    /// One decimal below 10 W, whole watts above, such as "3.6 W" or "24 W".
    public func formatted(locale: Locale = .autoupdatingCurrent) -> String {
        let digits = watts < 9.95 ? 1 : 0
        return watts.formatted(.number.precision(.fractionLength(digits)).locale(locale)) + " W"
    }
}

public struct Frequency: Hashable, Comparable, Sendable {
    public let hertz: Double

    public init(hertz: Double) {
        self.hertz = max(hertz, 0)
    }

    public init(megahertz: Double) {
        self.init(hertz: megahertz * 1_000_000)
    }

    public static func < (lhs: Frequency, rhs: Frequency) -> Bool {
        lhs.hertz < rhs.hertz
    }

    public var gigahertz: Double {
        hertz / 1_000_000_000
    }

    /// Gigahertz with up to two decimals, such as "3.15 GHz" or "0.4 GHz".
    public func formatted(locale: Locale = .autoupdatingCurrent) -> String {
        gigahertz.formatted(.number.precision(.fractionLength(0...2)).locale(locale)) + " GHz"
    }
}
