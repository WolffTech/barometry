// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Testing
@testable import BarometryKit

struct MemorySampleTests {
    private let pressure = MemoryPressure(level: .normal, percent: .zero)

    @Test func breaksDownPagesLikeActivityMonitor() {
        let pages = VMPageCounts(internal: 100, purgeable: 20, external: 30, wired: 40, compressor: 10)

        let sample = MemorySample(pages: pages, pageSize: 1000, total: ByteCount(bytes: 1_000_000), pressure: pressure)

        #expect(sample.app == ByteCount(bytes: 80_000))
        #expect(sample.wired == ByteCount(bytes: 40_000))
        #expect(sample.compressed == ByteCount(bytes: 10_000))
        #expect(sample.cached == ByteCount(bytes: 50_000))
        #expect(sample.used == ByteCount(bytes: 130_000))
    }

    @Test func clampsAppMemoryWhenPurgeableExceedsInternal() {
        let pages = VMPageCounts(internal: 10, purgeable: 20, external: 0, wired: 0, compressor: 0)

        let sample = MemorySample(pages: pages, pageSize: 1000, total: ByteCount(bytes: 1_000_000), pressure: pressure)

        #expect(sample.app == .zero)
    }

    @Test func pressureIsComplementOfAvailableLevel() {
        let pressure = MemoryPressure(kernelLevel: 1, availableLevel: 85)

        #expect(pressure.level == .normal)
        #expect(pressure.percent == Percent(0.15))
    }

    @Test(arguments: [(Int32(1), MemoryPressure.Level.normal), (2, .warning), (4, .critical), (0, .normal)])
    func mapsKernelPressureLevels(kernelValue: Int32, expected: MemoryPressure.Level) {
        #expect(MemoryPressure.Level(kernelValue: kernelValue) == expected)
    }
}
