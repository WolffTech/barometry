import AppKit
import BarometryKit
import Charts
import SwiftUI

/// Series colors, checked for color-blind separation and contrast in light and dark mode.
/// Every colored mark sits next to a text label, so color never carries meaning alone.
enum DashboardPalette {
    /// User CPU, performance cores, download, app memory.
    static let primary = Color.accentColor
    /// System CPU, efficiency cores, upload, wired memory.
    static let secondary = Color(red: 0xE0 / 255, green: 0x45 / 255, blue: 0x7B / 255)
    /// Compressed memory.
    static let tertiary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0xC9 / 255, green: 0x85 / 255, blue: 0, alpha: 1)
            : NSColor(srgbRed: 0xED / 255, green: 0xA1 / 255, blue: 0, alpha: 1)
    })
    static let track = Color.secondary.opacity(0.22)
}

struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator)
        }
    }
}

struct CardHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.callout.monospacedDigit())
            }
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

/// Circular gauge filled clockwise from 12 o'clock.
struct Ring<Label: View>: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 4
    @ViewBuilder var label: Label

    var body: some View {
        SegmentedRing(segments: [(fraction, color)], lineWidth: lineWidth) {
            label
        }
    }
}

extension Ring where Label == EmptyView {
    init(fraction: Double, color: Color, lineWidth: CGFloat = 4) {
        self.init(fraction: fraction, color: color, lineWidth: lineWidth) { EmptyView() }
    }
}

/// Circular gauge with consecutive colored segments separated by small gaps.
struct SegmentedRing<Label: View>: View {
    /// Fractions of the full circle, in drawing order.
    let segments: [(fraction: Double, color: Color)]
    var lineWidth: CGFloat = 4
    @ViewBuilder var label: Label

    private static var gap: CGFloat { 2 }

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height) - lineWidth
            let gapFraction = segments.count > 1 ? Self.gap / (.pi * max(diameter, 1)) : 0
            ZStack {
                Circle()
                    .stroke(DashboardPalette.track, lineWidth: lineWidth)
                ForEach(Array(arcs(gapFraction: gapFraction).enumerated()), id: \.offset) { _, arc in
                    Circle()
                        .trim(from: arc.start, to: arc.end)
                        .stroke(arc.color, lineWidth: lineWidth)
                        .rotationEffect(.degrees(-90))
                }
                label
            }
            .padding(lineWidth / 2)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func arcs(gapFraction: Double) -> [(start: Double, end: Double, color: Color)] {
        var start = 0.0
        var arcs: [(start: Double, end: Double, color: Color)] = []
        for segment in segments {
            let fraction = min(max(segment.fraction, 0), 1 - start)
            let end = start + fraction
            // Segments too small to show past the gap are skipped rather than drawn backwards.
            if fraction > gapFraction {
                arcs.append((start, end - gapFraction, segment.color))
            }
            start = end
        }
        return arcs
    }
}

/// Horizontal bar filled from the leading edge.
struct ProgressBar: View {
    let fraction: Double
    var color: Color = DashboardPalette.primary

    var body: some View {
        Capsule()
            .fill(DashboardPalette.track)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 6)
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
