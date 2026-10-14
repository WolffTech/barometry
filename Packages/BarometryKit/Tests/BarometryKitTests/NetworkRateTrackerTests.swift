// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Testing
@testable import BarometryKit

struct NetworkRateTrackerTests {
    private let start = ContinuousClock.now

    @Test func firstReadingHasNoRate() {
        var tracker = NetworkRateTracker()

        let first = tracker.update(interface: "en0", counters: NetworkCounters(received: 0, sent: 0), at: start)

        #expect(first == nil)
    }

    @Test func dividesByteDeltasByElapsedTime() throws {
        var tracker = NetworkRateTracker()
        _ = tracker.update(interface: "en0", counters: NetworkCounters(received: 1_000, sent: 500), at: start)

        let result = tracker.update(interface: "en0", counters: NetworkCounters(received: 5_000, sent: 1_500), at: start + .seconds(2))

        let sample = try #require(result)
        #expect(sample.download == ByteRate(bytesPerSecond: 2_000))
        #expect(sample.upload == ByteRate(bytesPerSecond: 500))
    }

    @Test func handlesCounterWraparound() throws {
        var tracker = NetworkRateTracker()
        _ = tracker.update(interface: "en0", counters: NetworkCounters(received: .max - 999, sent: 0), at: start)

        let result = tracker.update(interface: "en0", counters: NetworkCounters(received: 1_000, sent: 0), at: start + .seconds(1))

        // 1,000 bytes before the wrap, 1,000 after.
        let sample = try #require(result)
        #expect(sample.download == ByteRate(bytesPerSecond: 2_000))
    }

    @Test func restartsWhenInterfaceChanges() throws {
        var tracker = NetworkRateTracker()
        _ = tracker.update(interface: "en0", counters: NetworkCounters(received: 1_000_000, sent: 0), at: start)

        let afterSwitch = tracker.update(interface: "en1", counters: NetworkCounters(received: 10, sent: 0), at: start + .seconds(1))
        let next = tracker.update(interface: "en1", counters: NetworkCounters(received: 110, sent: 0), at: start + .seconds(2))

        #expect(afterSwitch == nil)
        let sample = try #require(next)
        #expect(sample.interface == "en1")
        #expect(sample.download == ByteRate(bytesPerSecond: 100))
    }
}
