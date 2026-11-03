// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

/// The instrument cluster style: needle dials for CPU, GPU, memory, and power, a network
/// trace, and small rings for battery and disk. Dials and rings each follow the section
/// order; the network trace always sits between them.
struct ClusterDashboard: View {
    let monitor: SystemMonitor
    /// Display names, such as "Wi-Fi", keyed by BSD name.
    let interfaceNames: [String: String]
    /// Shown sections in the user's order.
    let sections: [DashboardSection]

    @Environment(\.temperatureUnit) private var temperatureUnit

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(sections) { section in
                    dial(section)
                }
            }
            if sections.contains(.network) {
                networkTile
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(sections) { section in
                    ring(section)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 12)
    }

    @ViewBuilder private func dial(_ section: DashboardSection) -> some View {
        switch section {
        case .cpu:
            DialTile(
                title: "CPU",
                detail: monitor.frequencies?.cpu?.formatted(),
                value: monitor.cpu?.total.total.formatted() ?? missingValue,
                fraction: monitor.cpu?.total.total.fraction ?? 0,
                tint: DashboardSection.cpu.tint
            )
            .showsDetails(.cpu, cornerRadius: 14)
        case .gpu:
            if let gpu = monitor.gpu {
                DialTile(
                    title: "GPU",
                    detail: monitor.frequencies?.gpu?.formatted(),
                    value: gpu.utilization.formatted(),
                    fraction: gpu.utilization.fraction,
                    tint: DashboardSection.gpu.tint
                )
                .showsDetails(.gpu, cornerRadius: 14)
            }
        case .memory:
            if let memory = monitor.memory {
                DialTile(
                    title: "Memory",
                    detail: memory.pressure.level.name,
                    value: memory.pressure.percent.formatted(),
                    fraction: memory.pressure.percent.fraction,
                    tint: memory.pressure.level.tint
                )
                .showsDetails(.memory, cornerRadius: 14)
            }
        case .power:
            if let power = monitor.sensors?.systemPower {
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
        case .network, .disk:
            EmptyView()
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

    @ViewBuilder private func ring(_ section: DashboardSection) -> some View {
        switch section {
        case .power:
            if let battery = monitor.battery {
                RingTile(value: battery.charge.formatted(), detail: battery.stateDescription, fraction: battery.charge.fraction, tint: .green)
                    .accessibilityLabel("Battery")
                    .showsDetails(.power, cornerRadius: 14)
            }
        case .disk:
            if let disk = monitor.disk {
                RingTile(value: "\(Self.shortSize(disk.available)) free", detail: disk.name, fraction: disk.usage.fraction, tint: .blue)
                    .accessibilityLabel(disk.name)
                    .showsDetails(.disk, cornerRadius: 14)
            }
        case .cpu, .gpu, .memory, .network:
            EmptyView()
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
/// The fill and needle move in Core Animation layers, which the render server animates
/// without SwiftUI. Animating them in SwiftUI re-rendered the whole dashboard on every
/// frame, which cost about 20% CPU with a reading every second.
struct Dial: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DialArc(fraction: 1)
                    .stroke(
                        DashboardPalette.track,
                        style: StrokeStyle(lineWidth: DialGeometry.lineWidth(forWidth: geometry.size.width), lineCap: .round)
                    )
                DialTicks()
                    .stroke(.tertiary, lineWidth: 1)
                DialIndicator(fraction: min(max(fraction, 0), 1), tint: tint)
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(DialGeometry.width / DialGeometry.height, contentMode: .fit)
    }
}

/// The dial's fill, needle, and hub, drawn by `DialIndicatorView`.
private struct DialIndicator: NSViewRepresentable {
    let fraction: Double
    let tint: Color

    // Read so that SwiftUI calls `updateNSView` to re-resolve the colors when they change.
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeNSView(context: Context) -> DialIndicatorView {
        DialIndicatorView()
    }

    func updateNSView(_ view: DialIndicatorView, context: Context) {
        view.show(
            fraction: fraction,
            tint: tint.resolve(in: context.environment).cgColor,
            needle: Color.primary.resolve(in: context.environment).cgColor,
            animated: !reduceMotion
        )
    }
}

/// Layers for the moving parts of a dial. The fill is a full-sweep arc trimmed with
/// `strokeEnd`, and the needle is drawn at zero and rotated about the hub, so a new reading
/// only hands the render server two animations and never rebuilds a path.
private final class DialIndicatorView: NSView {
    private let arc = CAShapeLayer()
    private let needle = CAShapeLayer()
    private let hub = CAShapeLayer()
    /// The last fraction shown, or `nil` before the first, which appears without animating.
    private var fraction: Double?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        arc.fillColor = nil
        arc.lineCap = .round
        needle.fillColor = nil
        needle.lineCap = .round
        for sublayer in [arc, needle, hub] {
            layer?.addSublayer(sublayer)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // Matches SwiftUI's downward y axis, so the shared dial geometry applies unchanged.
    override var isFlipped: Bool { true }

    // Clicks and hovers belong to the tile around the dial.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        for sublayer in [arc, needle, hub] {
            sublayer.contentsScale = scale
        }
    }

    override func layout() {
        super.layout()
        let geometry = DialGeometry(bounds)
        let lineWidth = DialGeometry.lineWidth(forWidth: bounds.width)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        arc.frame = bounds
        arc.lineWidth = lineWidth
        arc.path = DialArc(fraction: 1).path(in: bounds).cgPath
        // Needle coordinates match the view's, with the anchor on the hub so it turns there.
        needle.bounds = CGRect(origin: .zero, size: bounds.size)
        needle.anchorPoint = bounds.width > 0 && bounds.height > 0
            ? CGPoint(x: geometry.center.x / bounds.width, y: geometry.center.y / bounds.height)
            : CGPoint(x: 0.5, y: 0.5)
        needle.position = geometry.center
        needle.lineWidth = lineWidth / 3
        needle.path = DialNeedle(fraction: 0).path(in: bounds).cgPath
        hub.frame = bounds
        hub.path = DialHub().path(in: bounds).cgPath
        CATransaction.commit()
    }

    func show(fraction: Double, tint: CGColor, needle needleColor: CGColor, animated: Bool) {
        // A sliver, not zero, so an empty dial still shows the arc's round cap.
        let strokeEnd = max(fraction, 0.001)
        let rotation = DialGeometry.sweepDegrees * fraction * .pi / 180
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        arc.strokeColor = tint
        needle.strokeColor = needleColor
        hub.fillColor = needleColor
        if animated, let previous = self.fraction, previous != fraction {
            // Start from what's on screen, in case a reading lands mid-animation.
            let shownEnd = arc.presentation()?.strokeEnd ?? arc.strokeEnd
            // The rotation reads back in -180°...180°, so angles past 180° come back negative.
            // Unwrap them into the dial's 0°...240°, splitting the unused 240°...360° gap, or
            // the needle would spin the long way round.
            let readRotation = (needle.presentation() ?? needle).value(forKeyPath: "transform.rotation.z") as? Double ?? 0
            let shownRotation = readRotation < -.pi / 3 ? readRotation + 2 * .pi : readRotation
            arc.add(Self.animation("strokeEnd", from: shownEnd, to: strokeEnd), forKey: "fill")
            needle.add(Self.animation("transform.rotation.z", from: shownRotation, to: rotation), forKey: "needle")
        }
        arc.strokeEnd = strokeEnd
        needle.setValue(rotation, forKeyPath: "transform.rotation.z")
        CATransaction.commit()
        self.fraction = fraction
    }

    /// The motion of SwiftUI's `.smooth`: a half-second spring without bounce.
    private static func animation(_ keyPath: String, from: Any?, to: Any) -> CASpringAnimation {
        let animation = CASpringAnimation(perceptualDuration: 0.5, bounce: 0)
        animation.keyPath = keyPath
        animation.fromValue = from
        animation.toValue = to
        animation.duration = animation.settlingDuration
        return animation
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

    static func lineWidth(forWidth width: CGFloat) -> CGFloat {
        width * 7 / Self.width
    }

    func point(at angle: Angle, radius: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * scale * cos(angle.radians),
            y: center.y + radius * scale * sin(angle.radians)
        )
    }
}

private nonisolated struct DialArc: Shape {
    let fraction: Double

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
    let fraction: Double

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
