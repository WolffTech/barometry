// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Testing
@testable import BarometryKit

@MainActor
struct CursorNudgerTests {
    private enum Step: Equatable {
        case nudge
        case sleep(Duration)
    }

    @Test func nudgesOnlyAfterAFullIntervalWithoutInput() async {
        var idleTimes: [Duration] = [.seconds(20), .seconds(60), .seconds(90), .seconds(5)]
        var steps: [Step] = []

        await CursorNudger.run(every: .seconds(60), idleTime: { idleTimes.removeFirst() }, nudge: { steps.append(.nudge) }) { duration in
            steps.append(.sleep(duration))
            if idleTimes.isEmpty { throw CancellationError() }
        }

        #expect(steps == [
            // Recent input: wait until a full interval has passed since it.
            .sleep(.seconds(40)),
            .nudge, .sleep(.seconds(60)),
            // Still idle, such as when the nudge didn't register: nudge again an interval later.
            .nudge, .sleep(.seconds(60)),
            .sleep(.seconds(55)),
        ])
    }
}
