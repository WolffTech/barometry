// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

/// Synthetic cursor movement that macOS, and apps watching for user activity, count as input.
/// Posting events needs the Accessibility permission; without it macOS drops them silently.
public enum CursorNudge {
    public static var isAllowed: Bool {
        CGPreflightPostEventAccess()
    }

    /// Asks macOS for permission, which also lists Barometry in Accessibility settings.
    /// Returns whether it's already allowed; a grant takes effect later in System Settings.
    @discardableResult
    public static func requestAccess() -> Bool {
        CGRequestPostEventAccess()
    }

    /// Time since the last input from any source, including these nudges.
    static func idleTime() -> Duration {
        .seconds(CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInputEventType))
    }

    /// Moves the cursor one point right and straight back, which resets the system idle time
    /// without visibly moving it.
    static func nudge() {
        guard let location = CGEvent(source: nil)?.location else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        for point in [CGPoint(x: location.x + 1, y: location.y), location] {
            CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
                .post(tap: .cghidEventTap)
        }
    }

    /// `kCGAnyInputEventType`, which Swift doesn't import.
    private static let anyInputEventType = CGEventType(rawValue: ~0)!
}

/// Nudges the cursor each time input has been idle for an interval, until dropped.
/// Noncopyable so the nudging can't outlive its owner.
@MainActor
struct CursorNudger: ~Copyable {
    private let task: Task<Void, Never>

    init(every interval: Duration) {
        task = Task {
            await Self.run(every: interval, idleTime: CursorNudge.idleTime, nudge: CursorNudge.nudge) {
                try await Task.sleep(for: $0)
            }
        }
    }

    deinit {
        task.cancel()
    }

    /// Runs until `sleep` throws, such as on cancellation. Recent input postpones the next nudge,
    /// so the cursor never moves while someone is using it.
    static func run(
        every interval: Duration,
        idleTime: () -> Duration,
        nudge: () -> Void,
        sleep: (Duration) async throws -> Void
    ) async {
        do {
            while true {
                let idle = idleTime()
                if idle >= interval {
                    nudge()
                    // A full interval even if the nudge didn't reset the idle time, such as
                    // without permission, so a failing nudge isn't retried in a tight loop.
                    try await sleep(interval)
                } else {
                    try await sleep(interval - idle)
                }
            }
        } catch {}
    }
}
