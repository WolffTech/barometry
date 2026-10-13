import Foundation

/// What a menu bar widget draws. Equatable so unchanged widgets can skip re-rendering.
public enum MenuBarWidgetContent: Equatable, Sendable {
    /// Recent fractions in 0...1, oldest first, at most `graphBarCount` long.
    case graph([Double])
    /// A fill level in 0...1.
    case gauge(Double)
    /// Two right-aligned lines, optionally led by fixed glyphs such as arrows. Glyphs sit in their
    /// own column beside the label so they stay put as the values change width. `widthTemplate`
    /// is the widest expected value text, used to reserve width so the item doesn't shift.
    case lines(top: String, bottom: String, glyphs: LineGlyphs?, widthTemplate: String)
    /// Values with short labels above them, side by side.
    case readouts([Readout])
    /// A battery filled to its charge level, beside the time or state over the charge.
    case battery(BatteryIndicator)

    public static let graphBarCount = 20
    static let missing = "—"

    static func make(
        module: MenuBarModule,
        style: MenuBarStyle,
        cpuHistory: some BidirectionalCollection<CPULoad>,
        gpuHistory: some BidirectionalCollection<Percent>,
        memory: MemorySample?,
        network: NetworkSample?,
        battery: BatterySample?,
        sensors: SensorSample?,
        temperatureUnit: TemperatureUnit,
        isKeepingAwake: Bool,
        locale: Locale
    ) -> MenuBarWidgetContent {
        // Keep Awake is marked on the battery, the module most tied to power.
        let badge: Badge? = isKeepingAwake ? .keepAwake : nil

        func percent(_ value: Percent?) -> Readout {
            Readout(label: module.label, value: value?.formatted(locale: locale) ?? missing, widthTemplate: "100%")
        }

        switch (module, style) {
        case (.cpu, .graphical):
            return .graph(cpuHistory.suffix(graphBarCount).map(\.total.fraction))
        case (.cpu, .text):
            return .readouts([percent(cpuHistory.last?.total)])
        case (.gpu, .graphical):
            return .graph(gpuHistory.suffix(graphBarCount).map(\.fraction))
        case (.gpu, .text):
            return .readouts([percent(gpuHistory.last)])
        case (.memory, .graphical):
            return .gauge(memory?.usage.fraction ?? 0)
        case (.memory, .text):
            return .readouts([percent(memory?.usage)])
        case (.network, _):
            return .lines(
                top: network?.upload.formatted(locale: locale) ?? missing,
                bottom: network?.download.formatted(locale: locale) ?? missing,
                glyphs: LineGlyphs(top: "↑", bottom: "↓"),
                widthTemplate: "888 KB/s"
            )
        case (.sensors, .graphical):
            return .lines(
                top: temperature(sensors, unit: temperatureUnit),
                bottom: power(sensors, locale: locale),
                glyphs: nil,
                widthTemplate: "88.8 W"
            )
        case (.sensors, .text):
            return .readouts([
                Readout(
                    label: "TEMP",
                    value: temperature(sensors, unit: temperatureUnit),
                    // Fahrenheit CPU temperatures usually run to three digits.
                    widthTemplate: temperatureUnit == .fahrenheit ? "188°" : "88°"
                ),
                Readout(label: "PWR", value: power(sensors, locale: locale), widthTemplate: "88.8 W"),
            ])
        case (.battery, .graphical):
            return .battery(battery.map { BatteryIndicator($0, badge: badge, locale: locale) } ?? .unavailable(badge: badge))
        case (.battery, .text):
            let charge = battery?.charge.formatted(locale: locale) ?? missing
            let isCharging = if case .charging = battery?.state { true } else { false }
            return .readouts([
                Readout(label: module.label, value: isCharging ? "⚡︎" + charge : charge, widthTemplate: "⚡︎100%", badge: badge),
            ])
        }
    }

    private static func temperature(_ sensors: SensorSample?, unit: TemperatureUnit) -> String {
        sensors?.cpuTemperature?.formatted(in: unit) ?? "\(missing)°"
    }

    private static func power(_ sensors: SensorSample?, locale: Locale) -> String {
        sensors?.systemPower?.formatted(locale: locale) ?? "\(missing) W"
    }
}

/// A symbol drawn beside a widget to show a mode is on.
public enum Badge: Equatable, Sendable {
    case keepAwake
}

public struct LineGlyphs: Equatable, Sendable {
    public let top: String
    public let bottom: String
}

public struct BatteryIndicator: Equatable, Sendable {
    /// Each status implies its icon, so the icon can't contradict the state.
    public enum Status: Equatable, Sendable {
        /// Drawn with a bolt.
        case charging(timeToFull: String)
        /// Drawn with the plain fill.
        case discharging(timeRemaining: String)
        /// Drawn with a plug, with "Full" above the charge.
        case charged
        /// On power but holding charge. Drawn with a plug, with pause bars above the charge.
        case paused
    }

    /// Fill level in 0...1.
    public let fraction: Double
    public let status: Status
    public let charge: String
    public let badge: Badge?

    /// The widest expected lines, used to reserve width so the item doesn't shift.
    public static let widthTemplate = (status: "8:88", charge: "100%")

    /// An empty battery with dashes, for when no reading is available.
    static func unavailable(badge: Badge?) -> BatteryIndicator {
        BatteryIndicator(
            fraction: 0,
            status: .discharging(timeRemaining: MenuBarWidgetContent.missing),
            charge: MenuBarWidgetContent.missing,
            badge: badge
        )
    }

    init(fraction: Double, status: Status, charge: String, badge: Badge? = nil) {
        self.fraction = fraction
        self.status = status
        self.charge = charge
        self.badge = badge
    }

    init(_ sample: BatterySample, badge: Badge? = nil, locale: Locale) {
        // Estimates are nil while macOS is still calculating.
        func clock(_ duration: Duration?) -> String {
            duration.map { $0.formatted(.time(pattern: .hourMinute).locale(locale)) } ?? "–:––"
        }
        let status: Status = switch sample.state {
        case .charging(let timeToFull): .charging(timeToFull: clock(timeToFull))
        case .discharging(let timeRemaining): .discharging(timeRemaining: clock(timeRemaining))
        case .charged: .charged
        case .notCharging: .paused
        }
        self.init(fraction: sample.charge.fraction, status: status, charge: sample.charge.formatted(locale: locale), badge: badge)
    }
}

public struct Readout: Equatable, Sendable {
    public let label: String
    public let value: String
    /// The widest expected value, used to reserve width so the item doesn't shift.
    public let widthTemplate: String
    /// Drawn before the label.
    public let badge: Badge?

    init(label: String, value: String, widthTemplate: String, badge: Badge? = nil) {
        self.label = label
        self.value = value
        self.widthTemplate = widthTemplate
        self.badge = badge
    }
}

extension SystemMonitor {
    public func widgetContent(
        for module: MenuBarModule,
        style: MenuBarStyle,
        temperatureUnit: TemperatureUnit,
        isKeepingAwake: Bool,
        locale: Locale = .autoupdatingCurrent
    ) -> MenuBarWidgetContent {
        .make(
            module: module,
            style: style,
            cpuHistory: cpuHistory,
            gpuHistory: gpuHistory,
            memory: memory,
            network: network,
            battery: battery,
            sensors: sensors,
            temperatureUnit: temperatureUnit,
            isKeepingAwake: isKeepingAwake,
            locale: locale
        )
    }
}
