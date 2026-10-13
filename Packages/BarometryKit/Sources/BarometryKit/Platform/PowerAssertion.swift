import IOKit.pwr_mgt

/// A held IOKit power assertion, released when this value is dropped. Noncopyable so it
/// can't be released twice or outlive its owner. macOS also releases it if the process exits.
struct PowerAssertion: ~Copyable {
    private let id: IOPMAssertionID

    /// Returns nil if macOS refuses the assertion.
    init?(type: String, name: String) {
        var id = IOPMAssertionID(kIOPMNullAssertionID)
        let result = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), name as CFString, &id)
        guard result == kIOReturnSuccess else { return nil }
        self.id = id
    }

    deinit {
        IOPMAssertionRelease(id)
    }
}
