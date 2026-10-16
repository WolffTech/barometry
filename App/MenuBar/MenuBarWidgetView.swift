// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

/// Height of status item content. Drawn in black and rendered as a template image,
/// so macOS tints it for the menu bar's appearance.
private let widgetHeight: CGFloat = 22

/// One or more modules side by side, as drawn into a single status item.
struct MenuBarItemView: View {
    let style: MenuBarStyle
    let widgets: [(module: MenuBarModule, content: MenuBarWidgetContent)]
    /// Black for the template image; the settings preview draws in the label color instead.
    var foreground = Color.black

    var body: some View {
        HStack(spacing: 10) {
            ForEach(widgets, id: \.module) { widget in
                MenuBarWidgetView(style: style, module: widget.module, content: widget.content)
            }
        }
        .foregroundStyle(foreground)
        .frame(height: widgetHeight)
        .padding(.horizontal, 2)
    }
}

struct MenuBarWidgetView: View {
    let style: MenuBarStyle
    let module: MenuBarModule
    let content: MenuBarWidgetContent

    var body: some View {
        HStack(spacing: 4) {
            // Text readouts carry their own labels, network's arrows already identify it,
            // and the cup identifies Keep Awake.
            if style == .graphical, module != .keepAwake {
                StackedLabel(text: module.label)
            }
            switch content {
            case .graph(let values):
                BarGraph(values: values)
            case .gauge(let fraction):
                FillGauge(fraction: fraction)
            case .lines(let top, let bottom, let glyphs, let widthTemplate):
                TwoLineText(top: top, bottom: bottom, glyphs: glyphs, widthTemplate: widthTemplate)
            case .readouts(let readouts):
                HStack(spacing: 8) {
                    ForEach(readouts, id: \.label) { readout in
                        ReadoutView(readout: readout)
                    }
                }
            case .battery(let indicator):
                BatteryIcon(fraction: indicator.fraction, glyph: BatteryGlyph(indicator.status))
                BatteryText(indicator: indicator)
            case .keepAwake:
                Image(systemName: KeepAwake.systemImage)
                    .font(.system(size: 14))
            }
        }
    }
}

extension KeepAwake {
    static let systemImage = "cup.and.heat.waves.fill"
}

/// Letters stacked vertically, such as "C P U".
private struct StackedLabel: View {
    let text: String

    var body: some View {
        VStack(spacing: -2) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, letter in
                Text(String(letter))
            }
        }
        // The three lines barely fit the item height. Without this, a combined item can
        // offer slightly less height and the letters drop out entirely.
        .fixedSize()
        .font(.system(size: 7, weight: .semibold))
    }
}

/// Outlined box of vertical bars, newest on the right.
private struct BarGraph: View {
    let values: [Double]

    private let barWidth: CGFloat = 1.5
    private let barSpacing: CGFloat = 0.5
    private let plotHeight: CGFloat = 14

    var body: some View {
        let barCount = CGFloat(MenuBarWidgetContent.graphBarCount)
        // One shape rather than a view per bar keeps re-rendering cheap.
        Path { path in
            let offset = MenuBarWidgetContent.graphBarCount - values.count
            for (index, value) in values.enumerated() {
                let height = max(value * plotHeight, 0.5)
                let x = CGFloat(offset + index) * (barWidth + barSpacing)
                path.addRect(CGRect(x: x, y: plotHeight - height, width: barWidth, height: height))
            }
        }
        .frame(width: barCount * barWidth + (barCount - 1) * barSpacing, height: plotHeight)
        .padding(2)
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(lineWidth: 1)
        }
    }
}

/// Vertical capsule filled from the bottom.
private struct FillGauge: View {
    let fraction: Double

    private let size = CGSize(width: 9, height: 18)
    private let inset: CGFloat = 2

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .strokeBorder(lineWidth: 1)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1)
                    .frame(height: (size.height - inset * 2) * min(max(fraction, 0), 1))
                    .padding(inset)
            }
    }
}

/// What's drawn over a battery's fill.
private enum BatteryGlyph {
    case bolt
    case plug

    init?(_ status: BatteryIndicator.Status) {
        switch status {
        case .charging: self = .bolt
        case .charged, .paused: self = .plug
        case .discharging: return nil
        }
    }

    /// Paths in `BatteryIcon`'s coordinate space, centered on the body.
    var path: Path {
        switch self {
        case .bolt:
            Path { path in
                path.addLines([
                    CGPoint(x: 11.9, y: 1.7), CGPoint(x: 7.7, y: 6.7), CGPoint(x: 10.4, y: 6.7),
                    CGPoint(x: 9.6, y: 10.3), CGPoint(x: 13.8, y: 5.3), CGPoint(x: 11.1, y: 5.3),
                ])
                path.closeSubpath()
            }
        case .plug:
            Path { path in
                // Prongs on the left, rounded body, cord to the right.
                path.addRect(CGRect(x: 7, y: 3.7, width: 2, height: 1.1))
                path.addRect(CGRect(x: 7, y: 7.2, width: 2, height: 1.1))
                path.addPath(UnevenRoundedRectangle(bottomTrailingRadius: 2, topTrailingRadius: 2)
                    .path(in: CGRect(x: 8.8, y: 2.7, width: 4.4, height: 6.6)))
                path.addRect(CGRect(x: 13, y: 5.4, width: 2.2, height: 1.2))
            }
        }
    }
}

/// Horizontal battery filled from the left, with an optional glyph cut out of the fill.
private struct BatteryIcon: View {
    let fraction: Double
    let glyph: BatteryGlyph?

    private let size = CGSize(width: 24, height: 12)
    private let shell = CGRect(x: 0.5, y: 0.5, width: 20.5, height: 11)
    private let fillBounds = CGRect(x: 2, y: 2, width: 17.5, height: 8)

    var body: some View {
        Canvas { context, _ in
            // Dimmed outline so the fill and glyph read first.
            var outline = context
            outline.opacity = 0.55
            outline.stroke(RoundedRectangle(cornerRadius: 3).path(in: shell), with: .foreground)
            outline.fill(Capsule().path(in: CGRect(x: 21.8, y: 4, width: 1.6, height: 4)), with: .foreground)

            let level = min(max(fraction, 0), 1)
            if level > 0 {
                // A layer so the cut-out clears only the fill, not the outline.
                context.drawLayer { layer in
                    var bounds = fillBounds
                    bounds.size.width *= level
                    layer.fill(RoundedRectangle(cornerRadius: 1.5).path(in: bounds), with: .foreground)
                    if let glyph {
                        // A gap around the glyph keeps it legible where it overlaps the fill.
                        layer.blendMode = .destinationOut
                        layer.fill(glyph.path, with: .foreground)
                        layer.stroke(glyph.path, with: .foreground, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                    }
                }
            }
            if let glyph {
                context.fill(glyph.path, with: .foreground)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// The time or state over the charge. Times sit right-aligned like other modules, while
/// "Full" and the pause bars center over the charge.
private struct BatteryText: View {
    let indicator: BatteryIndicator

    var body: some View {
        // The hidden template sets a minimum width; longer values still widen the item.
        ZStack(alignment: .trailing) {
            VStack(spacing: -2) {
                Text(BatteryIndicator.widthTemplate.status)
                Text(BatteryIndicator.widthTemplate.charge)
            }
            .hidden()
            VStack(alignment: .trailing, spacing: -2) {
                switch indicator.status {
                case .charging(let time), .discharging(let time):
                    Text(time)
                case .charged:
                    // Flexible width spans the stack, so the text centers over the charge.
                    Text("Full")
                        .frame(maxWidth: .infinity)
                case .paused:
                    Text(Image(systemName: "pause.fill"))
                        .frame(maxWidth: .infinity)
                }
                Text(indicator.charge)
            }
        }
        .font(.system(size: 9.5, weight: .medium).monospacedDigit())
        .lineLimit(1)
        // Keeps the stack at its natural width so the flexible line can't widen the item.
        .fixedSize()
    }
}

/// A small label centered over a large value, such as "CPU" over "22%".
private struct ReadoutView: View {
    let readout: Readout

    var body: some View {
        VStack(spacing: -2) {
            Text(readout.label)
                .tracking(0.4)
                .font(.system(size: 7, weight: .semibold))
            // The hidden template sets a minimum width; longer values still widen the item.
            ZStack {
                Text(readout.widthTemplate)
                    .hidden()
                Text(readout.value)
            }
            .font(.system(size: 13, weight: .bold).monospacedDigit())
        }
        .lineLimit(1)
        .fixedSize()
    }
}

private struct TwoLineText: View {
    let top: String
    let bottom: String
    let glyphs: LineGlyphs?
    let widthTemplate: String

    var body: some View {
        HStack(spacing: 3) {
            if let glyphs {
                VStack(spacing: -2) {
                    Text(glyphs.top)
                    Text(glyphs.bottom)
                }
            }
            // The hidden template sets a minimum width; longer values still widen the item.
            ZStack(alignment: .trailing) {
                Text(widthTemplate)
                    .hidden()
                VStack(alignment: .trailing, spacing: -2) {
                    Text(top)
                    Text(bottom)
                }
            }
        }
        .font(.system(size: 9.5, weight: .medium).monospacedDigit())
        .lineLimit(1)
    }
}
