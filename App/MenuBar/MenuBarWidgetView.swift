import BarometryKit
import SwiftUI

/// Height of status item content. Drawn in black and rendered as a template image,
/// so macOS tints it for the menu bar's appearance.
private let widgetHeight: CGFloat = 22

/// One or more modules side by side, as drawn into a single status item.
struct MenuBarItemView: View {
    let widgets: [(module: MenuBarModule, content: MenuBarWidgetContent)]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(widgets, id: \.module) { widget in
                MenuBarWidgetView(module: widget.module, content: widget.content)
            }
        }
        .foregroundStyle(.black)
        .frame(height: widgetHeight)
        .padding(.horizontal, 2)
    }
}

struct MenuBarWidgetView: View {
    let module: MenuBarModule
    let content: MenuBarWidgetContent

    var body: some View {
        HStack(spacing: 4) {
            StackedLabel(text: module.label)
            switch content {
            case .graph(let values):
                BarGraph(values: values)
            case .gauge(let fraction):
                FillGauge(fraction: fraction)
            case .lines(let top, let bottom, let widthTemplate):
                TwoLineText(top: top, bottom: bottom, widthTemplate: widthTemplate)
            }
        }
    }
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

private struct TwoLineText: View {
    let top: String
    let bottom: String
    let widthTemplate: String

    var body: some View {
        // The hidden template sets a minimum width; longer values still widen the item.
        ZStack(alignment: .trailing) {
            Text(widthTemplate)
                .hidden()
            VStack(alignment: .trailing, spacing: -2) {
                Text(top)
                Text(bottom)
            }
        }
        .font(.system(size: 9.5, weight: .medium).monospacedDigit())
        .lineLimit(1)
    }
}
