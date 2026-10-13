import BarometryKit
import Observation
import SwiftUI

/// Which section's details show beside the dashboard. Hovering an item shows its details,
/// and clicking pins them so they stay while the pointer moves elsewhere.
@Observable
final class DetailFocus {
    /// Wait before first showing details, so sweeping the pointer across the dashboard doesn't flash them.
    private static let openDelay = Duration.milliseconds(300)
    /// Wait before switching to another item's details, so crossing an item on the way to the
    /// details panel doesn't switch them.
    private static let switchDelay = Duration.milliseconds(150)
    /// Time to move from an item into its details, or between items, without closing them.
    private static let closeDelay = Duration.milliseconds(250)

    /// A section, and the frame of the item that shows it in the dashboard's global coordinates.
    struct Target: Equatable {
        let section: DashboardSection
        /// Nil when there's no item to line up with, such as when opened from the menu bar.
        let anchor: CGRect?
    }

    private(set) var hovered: Target?
    private(set) var pinned: Target?

    /// A pinned item wins over hovering, so the pointer can cross other items to reach its details.
    var shown: Target? { pinned ?? hovered }

    @ObservationIgnored private var pending: (section: DashboardSection?, task: Task<Void, Never>)?

    func pointerEntered(_ section: DashboardSection, anchor: CGRect) {
        let target = Target(section: section, anchor: anchor)
        if hovered == nil {
            schedule(section, after: Self.openDelay) { $0.hovered = target }
        } else if hovered != target {
            schedule(section, after: Self.switchDelay) { $0.hovered = target }
        } else {
            cancelPending()
        }
    }

    func pointerExited(_ section: DashboardSection) {
        // An exit can arrive after the next item's enter; only the item in play may close.
        guard hovered?.section == section || pending?.section == section else { return }
        scheduleClose()
    }

    func pointerOverDetails(_ isInside: Bool) {
        if isInside {
            cancelPending()
        } else {
            scheduleClose()
        }
    }

    /// Pins `section`, or unpins it if it's already pinned.
    func togglePin(_ section: DashboardSection, anchor: CGRect?) {
        cancelPending()
        if pinned?.section == section {
            pinned = nil
        } else {
            pinned = Target(section: section, anchor: anchor)
        }
    }

    /// Clears everything, then pins `section` if given.
    func reset(pinning section: DashboardSection?) {
        cancelPending()
        hovered = nil
        pinned = section.map { Target(section: $0, anchor: nil) }
    }

    private func scheduleClose() {
        schedule(nil, after: Self.closeDelay) { $0.hovered = nil }
    }

    private func schedule(_ section: DashboardSection?, after delay: Duration, _ change: @escaping (DetailFocus) -> Void) {
        cancelPending()
        let task = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            pending = nil
            change(self)
        }
        pending = (section, task)
    }

    private func cancelPending() {
        pending?.task.cancel()
        pending = nil
    }
}

extension View {
    /// Shows `section`'s details while hovered, and pins them when clicked.
    func showsDetails(_ section: DashboardSection, cornerRadius: CGFloat) -> some View {
        modifier(DetailTrigger(section: section, cornerRadius: cornerRadius))
    }
}

private struct DetailTrigger: ViewModifier {
    let section: DashboardSection
    let cornerRadius: CGFloat

    @Environment(DetailFocus.self) private var focus
    @State private var frame = CGRect.zero

    func body(content: Content) -> some View {
        Button {
            focus.togglePin(section, anchor: frame)
        } label: {
            content
                .contentShape(.rect(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.fill.tertiary)
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .onHover { isInside in
            if isInside {
                focus.pointerEntered(section, anchor: frame)
            } else {
                focus.pointerExited(section)
            }
        }
        .accessibilityHint("Shows details")
        .accessibilityAddTraits(focus.pinned?.section == section ? .isSelected : [])
    }

    /// Power has more than one tile, so only the one that opened the details is highlighted.
    private var isHighlighted: Bool {
        guard let shown = focus.shown, shown.section == section else { return false }
        return shown.anchor == nil || shown.anchor == frame
    }
}
