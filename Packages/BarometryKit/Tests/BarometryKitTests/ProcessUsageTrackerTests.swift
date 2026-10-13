import Foundation
import Testing
@testable import BarometryKit

struct ProcessUsageTrackerTests {
    private let start = ContinuousClock.now

    private func reading(_ pid: Int32, startTime: UInt64 = 1, cpuSeconds: Double = 0, joules: Double = 0, megabytes: UInt64 = 0) -> ProcessReading {
        ProcessReading(
            pid: pid,
            startTime: startTime,
            cpuTime: UInt64(cpuSeconds * 1e9),
            energy: UInt64(joules * 1e9),
            memory: megabytes * 1_000_000
        )
    }

    @Test func firstReadingHasNoUsage() {
        var tracker = ProcessUsageTracker()

        let result = tracker.update([reading(1)], at: start) { _ in "" }

        #expect(result == nil)
    }

    @Test func ranksEachMeasureOverElapsedTime() throws {
        var tracker = ProcessUsageTracker()
        _ = tracker.update([reading(1), reading(2), reading(3)], at: start) { _ in "" }

        let result = tracker.update(
            [
                reading(1, cpuSeconds: 3, joules: 1, megabytes: 100),
                reading(2, cpuSeconds: 1, joules: 4, megabytes: 300),
                reading(3, cpuSeconds: 0.2, joules: 2, megabytes: 200),
            ],
            at: start + .seconds(2)
        ) { "p\($0)" }

        let top = try #require(result)
        #expect(top.byCPU.map(\.id) == [1, 2, 3])
        #expect(top.byCPU.first?.cpu == CPUUsage(cores: 1.5))
        #expect(top.byCPU.first?.name == "p1")
        #expect(top.byMemory.map(\.id) == [2, 3, 1])
        #expect(top.byPower.map(\.id) == [2, 3, 1])
        #expect(top.byPower.first?.power == Power(watts: 2))
    }

    @Test func readingTooSoonKeepsTheEarlierBaseline() throws {
        var tracker = ProcessUsageTracker()
        _ = tracker.update([reading(1)], at: start) { _ in "" }

        let tooSoon = tracker.update([reading(1, cpuSeconds: 0.01)], at: start + .milliseconds(10)) { _ in "" }
        let later = tracker.update([reading(1, cpuSeconds: 1)], at: start + .seconds(1)) { _ in "" }

        #expect(tooSoon == nil)
        #expect(try #require(later).byCPU.first?.cpu == CPUUsage(cores: 1))
    }

    @Test func skipsNewAndReusedProcessIDs() throws {
        var tracker = ProcessUsageTracker()
        _ = tracker.update([reading(1, startTime: 10)], at: start) { _ in "" }

        let result = tracker.update(
            [reading(1, startTime: 20, cpuSeconds: 5), reading(2, cpuSeconds: 5)],
            at: start + .seconds(1)
        ) { _ in "" }

        #expect(try #require(result).byCPU.isEmpty)
    }

    @Test func keepsTheBusiestFewAndNamesOnlyThose() throws {
        var tracker = ProcessUsageTracker()
        let pids = Array(Int32(1)...10)
        _ = tracker.update(pids.map { reading($0) }, at: start) { _ in "" }
        var named: Set<Int32> = []

        let result = tracker.update(
            pids.map { reading($0, cpuSeconds: Double($0), joules: Double($0), megabytes: UInt64($0)) },
            at: start + .seconds(1)
        ) { pid in
            named.insert(pid)
            return ""
        }

        #expect(try #require(result).byCPU.map(\.id) == [10, 9, 8, 7])
        #expect(named == [10, 9, 8, 7])
    }

    @Test func formatsUsageAboveOneCore() {
        #expect(CPUUsage(cores: 1.43).formatted(locale: Locale(identifier: "en_US")) == "143.0%")
        #expect(CPUUsage(cores: 0.061).formatted(locale: Locale(identifier: "en_US")) == "6.1%")
    }
}
