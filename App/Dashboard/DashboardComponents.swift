import AppKit
import BarometryKit
import Charts
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
    static let track = Color.secondary.opacity(0.22)
}

/// One subsystem at a glance: an icon, a title and summary, a trend, and a headline value.
/// Expandable rows reveal their detail below when clicked.
struct GlanceRow<Trend: View, Value: View, Detail: View>: View {
    private let title: String
    private let summary: String?
    private let symbol: String
    private let tint: Color
    /// Nil for rows without detail.
    private let isExpanded: Binding<Bool>?
    private let trend: Trend
    private let value: Value
    private let detail: Detail

    @State private var isHovered = false

    init(
        title: String,
        summary: String?,
        symbol: String,
        tint: Color,
        isExpanded: Binding<Bool>,
        @ViewBuilder trend: () -> Trend,
        @ViewBuilder value: () -> Value,
        @ViewBuilder detail: () -> Detail
    ) {
        self.title = title
        self.summary = summary
        self.symbol = symbol
        self.tint = tint
        self.isExpanded = isExpanded
        self.trend = trend()
        self.value = value()
        self.detail = detail()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let isExpanded {
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        isExpanded.wrappedValue.toggle()
                    }
                } label: {
                    header
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityValue(isExpanded.wrappedValue ? "Expanded" : "Collapsed")
                if isExpanded.wrappedValue {
                    detail
                        // Lines up with the title, past the icon.
                        .padding(.leading, 38)
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                        .transition(.opacity)
                }
            } else {
                header
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            if isExpanded?.wrappedValue == true || (isExpanded != nil && isHovered) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.fill.quaternary)
            }
        }
        .onHover { isHovered = $0 }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint.gradient, in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
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
    }
}

extension GlanceRow where Detail == EmptyView {
    init(
        title: String,
        summary: String?,
        symbol: String,
        tint: Color,
        @ViewBuilder trend: () -> Trend,
        @ViewBuilder value: () -> Value
    ) {
        self.title = title
        self.summary = summary
        self.symbol = symbol
        self.tint = tint
        isExpanded = nil
        self.trend = trend()
        self.value = value()
        detail = EmptyView()
    }
}

/// Filled line of recent values, newest on the right.
struct Sparkline: View {
    /// Only recent samples, so the trend stays legible at sparkline width.
    private static let window = 30

    private let points: [(slot: Int, value: Double)]
    private let valueDomain: ClosedRange<Double>
    private let color: Color

    /// Values above `valueDomain` are clipped.
    init<Element>(_ history: History<Element>, color: Color, in valueDomain: ClosedRange<Double> = 0...1, value: (Element) -> Double) {
        let recent = history.suffix(Self.window)
        let offset = Self.window - recent.count
        points = recent.enumerated().map { (offset + $0.offset, value($0.element)) }
        self.valueDomain = valueDomain
        self.color = color
    }

    var body: some View {
        Chart(points, id: \.slot) { point in
            AreaMark(x: .value("Time", point.slot), y: .value("Value", point.value))
                .foregroundStyle(.linearGradient(colors: [color.opacity(0.4), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Time", point.slot), y: .value("Value", point.value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
        .chartXScale(domain: -0.5...(Double(Self.window) - 0.5))
        .chartYScale(domain: valueDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .clipped()
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

/// Upload grows up from the center line and download grows down, on one shared scale.
struct NetworkChart: View {
    let history: History<NetworkSample>
    /// The slot under the pointer, marked with a rule. Without a binding, the chart doesn't track the pointer.
    var hoverSlot: Binding<Int?>?

    var body: some View {
        let peak = max(history.map { max($0.upload.bytesPerSecond, $0.download.bytesPerSecond) }.max() ?? 0, 1_000)
        let chart = Chart {
            ForEach(history.slotted, id: \.slot) { slot, sample in
                BarMark(x: .value("Time", slot), y: .value("Rate", sample.upload.bytesPerSecond), width: .fixed(1.5))
                    .foregroundStyle(DashboardPalette.secondary)
                BarMark(x: .value("Time", slot), y: .value("Rate", -sample.download.bytesPerSecond), width: .fixed(1.5))
                    .foregroundStyle(DashboardPalette.primary)
            }
            RuleMark(y: .value("Rate", 0))
                .foregroundStyle(DashboardPalette.track)
                .lineStyle(StrokeStyle(lineWidth: 1))
            if let slot = hoverSlot?.wrappedValue, history.element(inSlot: slot) != nil {
                RuleMark(x: .value("Time", slot))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: history.slotDomain)
        .chartYScale(domain: -peak...peak)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        if let hoverSlot {
            chart.chartHoverSlot(hoverSlot)
        } else {
            chart
        }
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
}

extension View {
    /// Reports which history slot the pointer is over in a chart whose x values are slot numbers.
    func chartHoverSlot(_ slot: Binding<Int?>) -> some View {
        chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        guard case .active(let location) = phase, let plotFrame = proxy.plotFrame else {
                            slot.wrappedValue = nil
                            return
                        }
                        let x = location.x - geometry[plotFrame].origin.x
                        slot.wrappedValue = proxy.value(atX: x, as: Double.self).map { Int($0.rounded()) }
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

    /// Chart x domain covering every slot.
    var slotDomain: ClosedRange<Double> {
        -0.5...(Double(capacity) - 0.5)
    }
}

/// Non-nil parts joined with " · ", or nil if there are none.
func summary(_ parts: String?...) -> String? {
    let present = parts.compactMap(\.self)
    return present.isEmpty ? nil : present.joined(separator: " · ")
}

/// Shown in place of a reading that isn't available.
let missingValue = "—"
