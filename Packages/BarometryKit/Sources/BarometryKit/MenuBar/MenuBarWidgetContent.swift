import Foundation

/// What a menu bar widget draws. Equatable so unchanged widgets can skip re-rendering.
public enum MenuBarWidgetContent: Equatable, Sendable {
    /// Recent fractions in 0...1, oldest first, at most `graphBarCount` long.
    case graph([Double])
    /// A fill level in 0...1.
    case gauge(Double)
    /// Two right-aligned lines. `widthTemplate` is the widest expected text, used to reserve
    /// width so the item doesn't shift as values change.
    case lines(top: String, bottom: String, widthTemplate: String)

    public static let graphBarCount = 20
    static let missing = "—"

    static func make(
        module: MenuBarModule,
        cpuHistory: some Collection<CPULoad>,
        memory: MemorySample?,
        network: NetworkSample?,
        battery: BatterySample?,
        locale: Locale
    ) -> MenuBarWidgetContent {
        switch module {
        case .cpu:
            return .graph(cpuHistory.suffix(graphBarCount).map(\.total.fraction))
        case .gpu:
            // GPU utilization arrives with the sensors milestone.
            return .graph([])
        case .memory:
            return .gauge(memory?.usage.fraction ?? 0)
        case .network:
            return .lines(
                top: "↑ " + (network?.upload.formatted(locale: locale) ?? missing),
                bottom: "↓ " + (network?.download.formatted(locale: locale) ?? missing),
                widthTemplate: "↑ 888 KB/s"
            )
        case .sensors:
            // CPU temperature over system power; readings arrive with the sensors milestone.
            return .lines(top: "\(missing)°", bottom: "\(missing) W", widthTemplate: "888 W")
        case .battery:
            return .lines(
                top: battery.map { batteryStatus($0.state, locale: locale) } ?? missing,
                bottom: battery?.charge.formatted(locale: locale) ?? missing,
                widthTemplate: "⚡︎8:88"
            )
        }
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

extension SystemMonitor {
    public func widgetContent(for module: MenuBarModule, locale: Locale = .autoupdatingCurrent) -> MenuBarWidgetContent {
        .make(module: module, cpuHistory: cpuHistory, memory: memory, network: network, battery: battery, locale: locale)
    }
}
