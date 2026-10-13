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
    let section: DashboardSection

    var body: some View {
        Image(systemName: section.symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(section.tint.gradient, in: .rect(cornerRadius: 8))
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
        Chart(points, id: \.slot) { point in
            AreaMark(x: .value("Time", point.slot), y: .value("Value", point.value))
                .foregroundStyle(.linearGradient(colors: [color.opacity(0.4), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Time", point.slot), y: .value("Value", point.value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
        .chartXScale(domain: -0.5...(Double(window) - 0.5))
        .chartYScale(domain: valueDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            if showsGrid {
                AxisMarks(values: quarterLines) {
                    AxisGridLine()
                }
            }
        }
        .chartLegend(.hidden)
        .clipped()
    }
}

extension Sparkline {
    /// Grid lines at a quarter, half, and three quarters of the value domain.
    private var quarterLines: [Double] {
        [0.25, 0.5, 0.75].map { valueDomain.lowerBound + (valueDomain.upperBound - valueDomain.lowerBound) * $0 }
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
