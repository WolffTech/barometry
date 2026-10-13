import SystemConfiguration

/// Facts about this Mac that don't change while running.
public struct Machine: Sendable {
    /// The computer name from Sharing settings, such as "Nick's MacBook Pro".
    public let name: String?
    /// Such as "Apple M4 Pro".
    public let chip: String?

    public static func current() -> Machine {
        Machine(
            name: SCDynamicStoreCopyComputerName(nil, nil) as String?,
            chip: Sysctl.string("machdep.cpu.brand_string")
        )
    }
}
