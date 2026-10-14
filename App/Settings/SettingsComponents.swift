// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

extension View {
    /// A grouped form sized to its content, so each tab sets the window's height.
    func settingsPane() -> some View {
        formStyle(.grouped)
            .scrollDisabled(true)
            .frame(width: 500)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A picker drawn as labeled thumbnails, for choices that are easier to see than to name.
struct ThumbnailPicker<Value: Hashable, Thumbnail: View>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    @ViewBuilder let thumbnail: (Value) -> Thumbnail

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    VStack(spacing: 6) {
                        thumbnail(option.value)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(.fill.quaternary, in: .rect(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: isSelected ? 2 : 1)
                            }
                        Text(option.title)
                            .fontWeight(isSelected ? .semibold : .regular)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// A row title with an icon, an optional note under it, and a grip when the row can be dragged.
struct SettingsRowLabel: View {
    let title: String
    var note: String?
    let icon: IconTile
    var isMovable = false

    var body: some View {
        HStack(spacing: 8) {
            if isMovable {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let note {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Move Up and Move Down, for people who can't or don't want to drag.
struct MoveCommands: View {
    let index: Int
    let count: Int
    /// Takes SwiftUI `onMove` offsets.
    let move: (IndexSet, Int) -> Void

    var body: some View {
        Button("Move Up") { move([index], index - 1) }
            .disabled(index == 0)
        Button("Move Down") { move([index], index + 2) }
            .disabled(index == count - 1)
    }
}

extension MenuBarModule {
    var symbol: String {
        switch self {
        case .sensors: "thermometer.medium"
        case .battery: "battery.75percent"
        default: DashboardSection(self).symbol
        }
    }

    var tint: Color {
        switch self {
        case .sensors: .red
        case .battery: .green
        default: DashboardSection(self).tint
        }
    }
}

/// Separate items, or one item holding them all.
struct MenuBarLayoutThumbnail: View {
    let layout: MenuBarLayout

    var body: some View {
        HStack(spacing: layout == .individual ? 6 : 0) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: layout == .individual ? 3 : 0)
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 22, height: 12)
                    .overlay(alignment: .trailing) {
                        if layout == .combined, index < 2 {
                            Rectangle().fill(.background.opacity(0.6)).frame(width: 1)
                        }
                    }
            }
        }
        .clipShape(.rect(cornerRadius: 3))
        .accessibilityHidden(true)
    }
}

/// Dials in a grid, or rows with trends.
struct DashboardStyleThumbnail: View {
    let style: DashboardStyle

    private let sections: [DashboardSection] = [.cpu, .gpu, .memory, .power]

    var body: some View {
        Group {
            switch style {
            case .cluster:
                Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                    GridRow { dial(0.25, sections[0]); dial(0.6, sections[1]) }
                    GridRow { dial(0.45, sections[2]); dial(0.3, sections[3]) }
                }
            case .glance:
                VStack(spacing: 5) {
                    ForEach(sections) { section in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2).fill(section.tint).frame(width: 9, height: 9)
                            Capsule().fill(.secondary.opacity(0.5)).frame(width: 30, height: 3)
                            Capsule().fill(section.tint).frame(width: 26, height: 1.5)
                            Capsule().fill(.secondary).frame(width: 10, height: 3)
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func dial(_ fraction: Double, _ section: DashboardSection) -> some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75)
                .stroke(.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            Circle().trim(from: 0, to: 0.75 * fraction)
                .stroke(section.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .rotationEffect(.degrees(135))
        .frame(width: 18, height: 18)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(.fill.tertiary, in: .rect(cornerRadius: 4))
    }
}
