import Foundation
import Testing
@testable import BarometryKit

struct UnitsTests {
    private let locale = Locale(identifier: "en_US")

    @Test(arguments: [-0.5, 1.5, .nan, .infinity])
    func percentClampsInvalidInput(value: Double) {
        #expect((0...1).contains(Percent(value).fraction))
    }

    @Test func percentOfZeroTotalIsZero() {
        #expect(Percent(5, of: 0) == .zero)
    }

    @Test(arguments: [
        (0.0, "0 KB/s"),
        (400, "0 KB/s"),
        (600, "1 KB/s"),
        (22_000, "22 KB/s"),
        (999_700, "1 MB/s"),
        (1_500_000, "1.5 MB/s"),
        (12_400_000, "12 MB/s"),
    ])
    func formatsRatesInKilobytesOrLarger(bytesPerSecond: Double, expected: String) {
        #expect(ByteRate(bytesPerSecond: bytesPerSecond).formatted(locale: locale) == expected)
    }

    @Test func memoryUsesBinaryUnitsAndStorageUsesDecimal() {
        let bytes = ByteCount(bytes: 36 * 1024 * 1024 * 1024)

        #expect(bytes.formatted(.memory, locale: locale) == "36 GB")
        #expect(bytes.formatted(.file, locale: locale) == "38.65 GB")
    }

    @Test(arguments: [(Int64(870_000_000), "830 MB"), (1_288_490_189, "1.2 GB")])
    func compactSizeUsesWholeMegabytesOrOneDecimalGigabyte(bytes: Int64, expected: String) {
        #expect(ByteCount(bytes: bytes).formattedCompact(locale: locale) == expected)
    }

    @Test func diskUsageIsUsedFractionOfTotal() {
        let disk = DiskSample(name: "Macintosh HD", total: ByteCount(bytes: 1_000), available: ByteCount(bytes: 390))

        #expect(disk.usage == Percent(0.61))
    }
}
