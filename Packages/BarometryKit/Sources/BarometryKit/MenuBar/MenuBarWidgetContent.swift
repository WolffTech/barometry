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
        locale: Locale
    ) -> MenuBarWidgetContent {
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
            return .lines(
                top: battery.map { batteryStatus($0.state, locale: locale) } ?? missing,
                bottom: battery?.charge.formatted(locale: locale) ?? missing,
                glyphs: nil,
                widthTemplate: "⚡︎8:88"
            )
        case (.battery, .text):
            let charge = battery?.charge.formatted(locale: locale) ?? missing
            let isCharging = if case .charging = battery?.state { true } else { false }
            return .readouts([
                Readout(label: module.label, value: isCharging ? "⚡︎" + charge : charge, widthTemplate: "⚡︎100%"),
            ])
        }
    }

    private static func temperature(_ sensors: SensorSample?, unit: TemperatureUnit) -> String {
        sensors?.cpuTemperature?.formatted(in: unit) ?? "\(missing)°"
    }

    private static func power(_ sensors: SensorSample?, locale: Locale) -> String {
        sensors?.systemPower?.formatted(locale: locale) ?? "\(missing) W"
    }

    /// Time remaining on battery, time to full (with a bolt) while charging, or a short state word.
    static func batteryStatus(_ state: BatterySample.State, locale: Locale) -> String {
        func clock(_ duration: Duration) -> String {
            duration.formatted(.time(pattern: .hourMinute).locale(locale))
        }
        switch state {
        case .discharging(let timeRemaining):
            return timeRemaining.map(clock) ?? "–:––"
        case .charging(let timeToFull):
            return "⚡︎" + (timeToFull.map(clock) ?? "")
        case .charged:
            return "Full"
        case .notCharging:
            return "AC"
        }
    }
}

public struct LineGlyphs: Equatable, Sendable {
    public let top: String
    public let bottom: String
}

public struct Readout: Equatable, Sendable {
    public let label: String
    public let value: String
    /// The widest expected value, used to reserve width so the item doesn't shift.
    public let widthTemplate: String
}

extension SystemMonitor {
    public func widgetContent(
        for module: MenuBarModule,
        style: MenuBarStyle,
        temperatureUnit: TemperatureUnit,
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
            locale: locale
        )
    }
}
