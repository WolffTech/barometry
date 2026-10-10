import IOKit.ps

enum BatterySampler {
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
}
