// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Testing
@testable import BarometryKit

struct DiskActivityTrackerTests {
    private let start = ContinuousClock.now

    @Test func dividesByteDeltasByElapsedTime() throws {
        var tracker = DiskActivityTracker()
        #expect(tracker.update(DiskCounters(read: 1_000, written: 0), at: start) == nil)

        let result = tracker.update(DiskCounters(read: 9_000, written: 2_000), at: start + .seconds(2))

        #expect(try #require(result) == DiskActivity(read: ByteRate(bytesPerSecond: 4_000), write: ByteRate(bytesPerSecond: 1_000)))
    }

    @Test func ejectedDiskSkipsOneReading() {
        var tracker = DiskActivityTracker()
        _ = tracker.update(DiskCounters(read: 9_000, written: 9_000), at: start)

        #expect(tracker.update(DiskCounters(read: 5_000, written: 9_000), at: start + .seconds(1)) == nil)
        #expect(tracker.update(DiskCounters(read: 6_000, written: 9_000), at: start + .seconds(2)) != nil)
    }
}
