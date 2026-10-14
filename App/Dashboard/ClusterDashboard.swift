// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

/// The instrument cluster style: needle dials for CPU, GPU, memory, and power, a network
/// trace, and small rings for battery and disk.
struct ClusterDashboard: View {
    let monitor: SystemMonitor
    /// Display names, such as "Wi-Fi", keyed by BSD name.
    let interfaceNames: [String: String]
    let shows: (DashboardSection) -> Bool

    @Environment(\.temperatureUnit) private var temperatureUnit

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                dials
            }
            if shows(.network) {
                networkTile
            }
            LazyVGrid(columns: columns, spacing: 8) {
                rings
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 12)
    }

    @ViewBuilder private var dials: some View {
        if shows(.cpu) {
            DialTile(
                title: "CPU",
                detail: monitor.frequencies?.cpu?.formatted(),
                value: monitor.cpu?.total.total.formatted() ?? missingValue,
                fraction: monitor.cpu?.total.total.fraction ?? 0,
                tint: DashboardSection.cpu.tint
            )
            .showsDetails(.cpu, cornerRadius: 14)
        }
        if shows(.gpu), let gpu = monitor.gpu {
            DialTile(
                title: "GPU",
                detail: monitor.frequencies?.gpu?.formatted(),
                value: gpu.utilization.formatted(),
                fraction: gpu.utilization.fraction,
                tint: DashboardSection.gpu.tint
            )
            .showsDetails(.gpu, cornerRadius: 14)
        }
        if shows(.memory), let memory = monitor.memory {
            DialTile(
                title: "Memory",
                detail: memory.pressure.level.name,
                value: memory.used.formattedCompact(),
                fraction: memory.usage.fraction,
                tint: DashboardSection.memory.tint
            )
            .showsDetails(.memory, cornerRadius: 14)
        }
        if shows(.power), let power = monitor.sensors?.systemPower {
            // Macs draw anywhere from a few watts to well over 100, so the dial spans the
            // recent peak rather than a fixed range.
            let peak = max(monitor.powerHistory.map(\.watts).max() ?? 0, 20)
            DialTile(
                title: "Power",
                detail: monitor.sensors?.cpuTemperature?.formatted(in: temperatureUnit),
                value: power.formatted(),
                fraction: power.watts / peak,
                tint: DashboardSection.power.tint
            )
            .showsDetails(.power, cornerRadius: 14)
        }
    }

    private var networkTile: some View {
        let network = monitor.network
        return ClusterTile {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(network.flatMap { summary("Network", interfaceNames[$0.interface] ?? $0.interface) } ?? "Network")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    rate(network?.upload, color: DashboardPalette.secondary, label: "Upload")
                    rate(network?.download, color: DashboardPalette.primary, label: "Download")
                }
                .fixedSize()
                RateChart(network: monitor.networkHistory)
                    .frame(height: 40)
                    .accessibilityHidden(true)
            }
        }
        .showsDetails(.network, cornerRadius: 14)
    }

    private func rate(_ rate: ByteRate?, color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(rate?.formatted() ?? missingValue)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var rings: some View {
        if shows(.power), let battery = monitor.battery {
            RingTile(value: battery.charge.formatted(), detail: battery.stateDescription, fraction: battery.charge.fraction, tint: .green)
                .accessibilityLabel("Battery")
                .showsDetails(.power, cornerRadius: 14)
        }
        if shows(.disk), let disk = monitor.disk {
            RingTile(value: "\(Self.shortSize(disk.available)) free", detail: disk.name, fraction: disk.usage.fraction, tint: .blue)
                .accessibilityLabel(disk.name)
                .showsDetails(.disk, cornerRadius: 14)
        }
    }
}

extension ClusterDashboard {
    /// Short storage size for a small tile: whole gigabytes, such as "364 GB", or terabytes
    /// as Finder shows them, such as "2.4 TB".
    static func shortSize(_ size: ByteCount) -> String {
        let gigabytes = (Double(size.bytes) / 1e9).rounded()
        guard gigabytes < 1000 else { return size.bytes.formatted(.byteCount(style: .file, allowedUnits: .tb)) }
        return Int64(gigabytes * 1e9).formatted(.byteCount(style: .file, allowedUnits: .gb))
    }
}

/// Rounded tile that groups one reading.
struct ClusterTile<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.fill.quaternary, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
    }
}

private struct DialTile: View {
    let title: String
    let detail: String?
    let value: String
    let fraction: Double
    let tint: Color

    var body: some View {
        ClusterTile {
            VStack(spacing: 0) {
                Dial(fraction: fraction, tint: tint)
                    .accessibilityHidden(true)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    // Sits in the dial's open bottom.
                    .padding(.top, -10)
                Text(summary(title, detail) ?? title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RingTile: View {
    let value: String
    let detail: String
    let fraction: Double
    let tint: Color

    var body: some View {
        ClusterTile {
            HStack(spacing: 10) {
                Ring(fraction: fraction, tint: tint)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(value)
                        .font(.headline)
                        .monospacedDigit()
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Barometer-style gauge: a 240° arc filled to `fraction`, with ticks and a needle.
/// Not animated: SwiftUI re-renders the whole dashboard on every animation frame, which
/// cost about 20% CPU with a reading every second.
struct Dial: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        let fraction = min(max(fraction, 0), 1)
        GeometryReader { geometry in
            let lineWidth = geometry.size.width * 7 / DialGeometry.width
            ZStack {
                DialArc(fraction: 1)
                    .stroke(DashboardPalette.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                DialArc(fraction: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                DialTicks()
                    .stroke(.tertiary, lineWidth: 1)
                DialNeedle(fraction: fraction)
                    .stroke(.primary, style: StrokeStyle(lineWidth: lineWidth / 3, lineCap: .round))
                DialHub()
                    .fill(.primary)
            }
        }
        .aspectRatio(DialGeometry.width / DialGeometry.height, contentMode: .fit)
    }
}

/// Dial layout in a 120 × 84 design space, scaled to the drawing rect. The dial shapes are
/// nonisolated because SwiftUI may call `Shape.path(in:)` off the main actor.
private nonisolated struct DialGeometry {
    static let width = 120.0
    static let height = 84.0
    static let startDegrees = 150.0
    static let sweepDegrees = 240.0

    let center: CGPoint
    let scale: CGFloat

    init(_ rect: CGRect) {
        scale = rect.width / Self.width
        center = CGPoint(x: rect.midX, y: rect.minY + 58 * scale)
    }

    /// Angle for `fraction` of the sweep, clockwise from the lower left.
    static func angle(_ fraction: Double) -> Angle {
        .degrees(startDegrees + sweepDegrees * fraction)
    }

    func point(at angle: Angle, radius: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * scale * cos(angle.radians),
            y: center.y + radius * scale * sin(angle.radians)
        )
    }
}

private nonisolated struct DialArc: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let geometry = DialGeometry(rect)
        var path = Path()
        // SwiftUI's y axis points down, so increasing angles run clockwise on screen.
        path.addArc(
            center: geometry.center,
            radius: 44 * geometry.scale,
            startAngle: DialGeometry.angle(0),
            endAngle: DialGeometry.angle(fraction),
            clockwise: false
        )
        return path
    }
}

private nonisolated struct DialTicks: Shape {
    func path(in rect: CGRect) -> Path {
        let geometry = DialGeometry(rect)
        var path = Path()
        for index in 0...10 {
            let angle = DialGeometry.angle(Double(index) / 10)
            path.move(to: geometry.point(at: angle, radius: 35))
            path.addLine(to: geometry.point(at: angle, radius: index % 5 == 0 ? 29 : 32))
        }
        return path
    }
}

private nonisolated struct DialNeedle: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let geometry = DialGeometry(rect)
        var path = Path()
        path.move(to: geometry.center)
        path.addLine(to: geometry.point(at: DialGeometry.angle(fraction), radius: 30))
        return path
    }
}

private nonisolated struct DialHub: Shape {
    func path(in rect: CGRect) -> Path {
        let geometry = DialGeometry(rect)
        let radius = 4 * geometry.scale
        return Path(ellipseIn: CGRect(x: geometry.center.x - radius, y: geometry.center.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// Circular progress ring filled clockwise from the top.
struct Ring: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(DashboardPalette.track, lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(2)
    }
}
