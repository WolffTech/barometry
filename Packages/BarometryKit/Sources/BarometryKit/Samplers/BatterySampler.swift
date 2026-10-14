// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import IOKit
import IOKit.ps

enum BatterySampler {
    /// Whether this Mac has an internal battery, such as a MacBook rather than a Mac mini.
    static var isInstalled: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }

        return sources.contains { source in
            let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
            return description?[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
    }

    /// Returns nil on Macs without an internal battery.
    static func sample() -> BatterySample? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        return sources.lazy.compactMap { source in
            (IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any])
                .flatMap(BatterySample.init(powerSourceDescription:))
        }.first
    }

    /// Reads cycle count and capacity from the battery's registry entry.
    static func health() -> BatteryHealth? {
        let battery = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery"))
        guard battery != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(battery) }

        var properties: [String: Any] = [:]
        for key in ["CycleCount", "DesignCapacity", "AppleRawMaxCapacity", "BatteryData"] {
            properties[key] = IORegistryEntryCreateCFProperty(battery, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        return BatteryHealth(registry: properties)
    }
}
