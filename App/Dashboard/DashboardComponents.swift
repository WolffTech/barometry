// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import BarometryKit
import SwiftUI

extension EnvironmentValues {
    @Entry var temperatureUnit: TemperatureUnit = .celsius
}

/// Series colors, checked for color-blind separation and contrast in light and dark mode.
/// Every colored mark sits next to a text label, so color never carries meaning alone.
enum DashboardPalette {
    /// User CPU, download, app memory.
    static let primary = Color.accentColor
    /// System CPU, upload, wired memory.
    static let secondary = Color(red: 0xE0 / 255, green: 0x45 / 255, blue: 0x7B / 255)
    /// Compressed memory.
    static let tertiary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0xC9 / 255, green: 0x85 / 255, blue: 0, alpha: 1)
            : NSColor(srgbRed: 0xED / 255, green: 0xA1 / 255, blue: 0, alpha: 1)
    })
    /// High memory pressure. System yellow is unreadable as text on light backgrounds, so
    /// light mode uses a darker amber.
    static let warning = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .systemYellow
            : NSColor(srgbRed: 0x9A / 255, green: 0x67 / 255, blue: 0, alpha: 1)
    })
    static let track = Color.secondary.opacity(0.22)
    static let grid = Color.secondary.opacity(0.3)
}

extension DashboardSection {
    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .gpu: "cube.transparent"
        case .memory: "memorychip"
        case .network: "arrow.up.arrow.down"
        case .power: "bolt.fill"
        case .disk: "internaldrive"
        }
    }

    var tint: Color {
        switch self {
        case .cpu: .blue
        case .gpu: .indigo
        case .memory: .pink
        case .network: .cyan
        case .power: .orange
        case .disk: .gray
        }
    }
}

/// White symbol on a tinted rounded square.
struct IconTile: View {
    let symbol: String
    let tint: Color
    let size: CGFloat

    init(symbol: String, tint: Color, size: CGFloat = 28) {
        self.symbol = symbol
        self.tint = tint
        self.size = size
    }

    init(section: DashboardSection, size: CGFloat = 28) {
        self.init(symbol: section.symbol, tint: section.tint, size: size)
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: .rect(cornerRadius: size * 0.29))
            .accessibilityHidden(true)
    }
}

/// One subsystem at a glance: an icon, a title and summary, a trend, and a headline value.
struct GlanceRow<Trend: View, Value: View>: View {
    let section: DashboardSection
    var title: String?
    let summary: String?
    @ViewBuilder let trend: Trend
    @ViewBuilder let value: Value

    var body: some View {
        HStack(spacing: 10) {
            IconTile(section: section)
            VStack(alignment: .leading, spacing: 1) {
                Text(title ?? section.name)
                    .fontWeight(.semibold)
                if let summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            trend
                .frame(width: 56, height: 22)
                .accessibilityHidden(true)
            value
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .fixedSize()
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .showsDetails(section, cornerRadius: 12)
    }
}

/// Top of a details panel: the section's icon, a large value, and a summary below it.
struct DetailsHeader: View {
    let section: DashboardSection
    let value: String
    let summary: String?

    var body: some View {
        HStack(spacing: 10) {
            IconTile(section: section)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                if let summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(section.name)
    }
}

/// Small uppercase heading for a group within a details panel.
struct DetailsHeading: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Filled line of recent values, newest on the right.
struct Sparkline: View {
    /// Samples a row's sparkline shows: few enough that the trend stays legible at its width.
    static let rowWindow = 30

    private let points: [(slot: Int, value: Double)]
    private let window: Int
    private let valueDomain: ClosedRange<Double>
    private let color: Color
    private let showsGrid: Bool

    /// Shows the last `window` samples. Values above `valueDomain` are clipped.
    init<Element>(
        _ history: History<Element>,
        color: Color,
        in valueDomain: ClosedRange<Double> = 0...1,
        window: Int = rowWindow,
        showsGrid: Bool = false,
        value: (Element) -> Double
    ) {
        let recent = history.suffix(window)
        let offset = window - recent.count
        points = recent.enumerated().map { (offset + $0.offset, value($0.element)) }
        self.window = window
        self.valueDomain = valueDomain
        self.color = color
        self.showsGrid = showsGrid
    }

    var body: some View {
        ZStack {
            if showsGrid {
                GridLines(values: quarterLines, domain: valueDomain)
                    .stroke(DashboardPalette.grid, lineWidth: 1)
            }
            TrendShape(points: points, slots: window, domain: valueDomain, closed: true)
                .fill(.linearGradient(colors: [color.opacity(0.4), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            TrendShape(points: points, slots: window, domain: valueDomain, closed: false)
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .clipped()
    }
}

extension Sparkline {
    /// Grid lines at a quarter, half, and three quarters of the value domain.
    private var quarterLines: [Double] {
        [0.25, 0.5, 0.75].map { valueDomain.lowerBound + (valueDomain.upperBound - valueDomain.lowerBound) * $0 }
    }
}

/// Places history slots and values in a drawing rect: slots are evenly spaced columns,
/// oldest on the left, and values run up from the bottom of `domain`. Shapes are nonisolated
/// because SwiftUI may call `Shape.path(in:)` off the main actor.
nonisolated struct PlotScale {
    let rect: CGRect
    let slots: Int
    let domain: ClosedRange<Double>

    /// The center of `slot`'s column.
    func x(_ slot: Int) -> CGFloat {
        rect.minX + (CGFloat(slot) + 0.5) / CGFloat(slots) * rect.width
    }

    func y(_ value: Double) -> CGFloat {
        rect.maxY - (value - domain.lowerBound) / (domain.upperBound - domain.lowerBound) * rect.height
    }

    /// The slot whose column contains `x`, which may fall outside the plot.
    func slot(atX x: CGFloat) -> Int {
        Int(((x - rect.minX) / rect.width * CGFloat(slots) - 0.5).rounded())
    }
}

/// A line through values, or with `closed`, the area between it and the bottom of the domain.
nonisolated struct TrendShape: Shape {
    let points: [(slot: Int, value: Double)]
    let slots: Int
    let domain: ClosedRange<Double>
    let closed: Bool

    func path(in rect: CGRect) -> Path {
        let scale = PlotScale(rect: rect, slots: slots, domain: domain)
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }
        path.addLines(points.map { CGPoint(x: scale.x($0.slot), y: scale.y($0.value)) })
        if closed {
            path.addLine(to: CGPoint(x: scale.x(last.slot), y: rect.maxY))
            path.addLine(to: CGPoint(x: scale.x(first.slot), y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// Thin vertical bars, each spanning two values in its slot's column.
nonisolated struct BarsShape: Shape {
    static let barWidth: CGFloat = 1.5

    let bars: [(slot: Int, from: Double, to: Double)]
    let slots: Int
    let domain: ClosedRange<Double>

    func path(in rect: CGRect) -> Path {
        let scale = PlotScale(rect: rect, slots: slots, domain: domain)
        var path = Path()
        for bar in bars {
            let from = scale.y(bar.from)
            let to = scale.y(bar.to)
            path.addRect(CGRect(x: scale.x(bar.slot) - Self.barWidth / 2, y: min(from, to), width: Self.barWidth, height: abs(to - from)))
        }
        return path
    }
}

/// Horizontal lines across the plot at the given values.
nonisolated struct GridLines: Shape {
    let values: [Double]
    let domain: ClosedRange<Double>

    func path(in rect: CGRect) -> Path {
        let scale = PlotScale(rect: rect, slots: 1, domain: domain)
        var path = Path()
        for value in values {
            let y = scale.y(value)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

/// A vertical line down the center of a slot's column.
nonisolated struct SlotRule: Shape {
    let slot: Int
    let slots: Int

    func path(in rect: CGRect) -> Path {
        let x = PlotScale(rect: rect, slots: slots, domain: 0...1).x(slot)
        var path = Path()
        path.move(to: CGPoint(x: x, y: rect.minY))
        path.addLine(to: CGPoint(x: x, y: rect.maxY))
        return path
    }
}

/// Secondary label and right-aligned value.
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
    }
}

/// Detail row with a bar showing the value's share of its maximum.
struct MeterRow: View {
    let label: String
    let value: String
    let fraction: Double
    var color: Color = DashboardPalette.primary

    var body: some View {
        VStack(spacing: 4) {
            DetailRow(label: label, value: value)
            ProgressBar(fraction: fraction, color: color)
        }
    }
}

/// Colored dot, label, and right-aligned value.
struct LegendRow: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
            Spacer(minLength: 4)
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
    }
}

/// Horizontal bar filled from the leading edge.
struct ProgressBar: View {
    let fraction: Double
    var color: Color = DashboardPalette.primary

    var body: some View {
        SegmentedBar(segments: [(fraction, color)])
    }
}

/// Horizontal bar with consecutive colored segments, each a fraction of the full width.
struct SegmentedBar: View {
    let segments: [(fraction: Double, color: Color)]

    var body: some View {
        Capsule()
            .fill(DashboardPalette.track)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            Rectangle()
                                .fill(segment.color)
                                .frame(width: geometry.size.width * min(max(segment.fraction, 0), 1))
                        }
                    }
                }
                .clipShape(.capsule)
            }
            .frame(height: 6)
    }
}

/// Two rates on one shared scale, such as upload and download: the upper grows up from the
/// center line in the secondary color, and the lower grows down in the primary color.
struct RateChart<Element>: View {
    let history: History<Element>
    let upper: (Element) -> ByteRate
    let lower: (Element) -> ByteRate
    /// The slot under the pointer, marked with a rule. Without a binding, the chart doesn't track the pointer.
    var hoverSlot: Binding<Int?>?

    var body: some View {
        let peak = max(history.map { max(upper($0).bytesPerSecond, lower($0).bytesPerSecond) }.max() ?? 0, 1_000)
        let slotted = history.slotted
        let domain = -peak...peak
        let chart = ZStack {
            BarsShape(bars: slotted.map { ($0.slot, 0, upper($0.element).bytesPerSecond) }, slots: history.capacity, domain: domain)
                .fill(DashboardPalette.secondary)
            BarsShape(bars: slotted.map { ($0.slot, -lower($0.element).bytesPerSecond, 0) }, slots: history.capacity, domain: domain)
                .fill(DashboardPalette.primary)
            GridLines(values: [0], domain: domain)
                .stroke(DashboardPalette.track, lineWidth: 1)
            if let slot = hoverSlot?.wrappedValue, history.element(inSlot: slot) != nil {
                SlotRule(slot: slot, slots: history.capacity)
                    .stroke(.secondary, lineWidth: 1)
            }
        }
        if let hoverSlot {
            chart.hoverSlot(hoverSlot, slots: history.capacity)
        } else {
            chart
        }
    }
}

extension RateChart where Element == NetworkSample {
    init(network history: History<NetworkSample>, hoverSlot: Binding<Int?>? = nil) {
        self.init(history: history, upper: \.upload, lower: \.download, hoverSlot: hoverSlot)
    }
}

/// The busiest few processes by one measure, with bars relative to the busiest.
/// Shows placeholder rows until the first usage arrives, so the details don't jump.
struct ProcessList: View {
    let title: String
    let processes: [ProcessUsage]?
    let tint: Color
    let measure: (ProcessUsage) -> Double
    let value: (ProcessUsage) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DetailsHeading(title)
            if let processes {
                let top = processes.map(measure).max() ?? 0
                ForEach(processes) { process in
                    row(name: process.name, fraction: top > 0 ? measure(process) / top : 0, value: value(process))
                }
                if processes.isEmpty {
                    Text("No processes to show")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(0..<4, id: \.self) { _ in
                    row(name: "Process name", fraction: 0, value: "0.0%")
                }
                .redacted(reason: .placeholder)
            }
            Text("Your processes only")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func row(name: String, fraction: Double, value: String) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            ProgressBar(fraction: fraction, color: tint)
                .frame(width: 60)
            Text(value)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
        }
        .font(.callout)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(value)
    }
}

extension Power {
    /// Milliwatts below a watt, so idle processes don't all read "0.0 W".
    var processFormatted: String {
        watts < 0.995 ? "\((watts * 1000).formatted(.number.precision(.fractionLength(0)))) mW" : formatted()
    }
}

extension BatterySample {
    /// What the battery is doing, such as "6:12 left" or "Charged".
    var stateDescription: String {
        switch state {
        case .charging(let timeToFull):
            timeToFull.map { "Full in \($0.formatted(.time(pattern: .hourMinute)))" } ?? "Charging"
        case .charged:
            "Charged"
        case .notCharging:
            "Not charging"
        case .discharging(let timeRemaining):
            timeRemaining.map { "\($0.formatted(.time(pattern: .hourMinute))) left" } ?? "On battery"
        }
    }

    /// Charge and state, such as "87% · 6:12 left".
    var chargeSummary: String {
        "\(charge.formatted()) · \(stateDescription)"
    }
}

extension MemoryPressure.Level {
    var name: String {
        switch self {
        case .normal: "Normal"
        case .warning: "High"
        case .critical: "Critical"
        }
    }

    /// Normal keeps the section's color; higher levels follow Activity Monitor's yellow and red.
    var tint: Color {
        switch self {
        case .normal: DashboardSection.memory.tint
        case .warning: DashboardPalette.warning
        case .critical: .red
        }
    }

    /// Headline values stay the primary color until pressure rises.
    var valueStyle: Color {
        self == .normal ? .primary : tint
    }
}

extension View {
    /// Reports which history slot the pointer is over in a plot spanning `slots` slots.
    func hoverSlot(_ slot: Binding<Int?>, slots: Int) -> some View {
        overlay {
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        guard case .active(let location) = phase else {
                            slot.wrappedValue = nil
                            return
                        }
                        slot.wrappedValue = PlotScale(rect: CGRect(origin: .zero, size: geometry.size), slots: slots, domain: 0...1)
                            .slot(atX: location.x)
                    }
            }
        }
    }
}

extension History {
    /// Elements paired with a chart slot, right-aligned so the newest sample is always in
    /// the last slot and the chart fills in from the right.
    var slotted: [(slot: Int, element: Element)] {
        let offset = capacity - count
        return enumerated().map { (offset + $0.offset, $0.element) }
    }

    /// The element drawn in `slot`, if any.
    func element(inSlot slot: Int) -> Element? {
        let index = slot - (capacity - count)
        return indices.contains(index) ? self[index] : nil
    }
}

/// Non-nil parts joined with " · ", or nil if there are none.
func summary(_ parts: String?...) -> String? {
    let present = parts.compactMap(\.self)
    return present.isEmpty ? nil : present.joined(separator: " · ")
}

/// Shown in place of a reading that isn't available.
let missingValue = "—"

extension ProcessList {
    static func byCPU(_ processes: TopProcesses?, title: String = "Top processes", tint: Color) -> some View {
        ProcessList(title: title, processes: processes?.byCPU, tint: tint, measure: \.cpu.cores) { $0.cpu.formatted() }
            .padding(.top, 4)
    }
}
