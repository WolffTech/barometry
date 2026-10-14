// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import IOKit

/// Reads GPU utilization from the accelerator driver's `PerformanceStatistics`.
/// The keys are undocumented but need no entitlement.
enum GPUSampler {
    static func sample() -> GPUSample? {
        let accelerator = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOAccelerator"))
        guard accelerator != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(accelerator) }

        guard let statistics = IORegistryEntryCreateCFProperty(accelerator, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? [String: Any],
            let utilization = statistics["Device Utilization %"] as? Int
        else { return nil }

        return GPUSample(
            utilization: Percent(Double(utilization) / 100),
            memoryInUse: (statistics["In use system memory"] as? Int).map { ByteCount(bytes: Int64($0)) }
        )
    }
}
