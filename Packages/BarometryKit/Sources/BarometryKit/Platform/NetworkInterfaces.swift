// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import SystemConfiguration

public struct NetworkInterface: Hashable, Sendable, Identifiable {
    /// BSD name such as "en0".
    public let bsdName: String
    /// Localized name such as "Wi-Fi".
    public let displayName: String

    public var id: String { bsdName }
}

public enum NetworkInterfaces {
    /// Interfaces known to System Settings, in its order.
    public static func available() -> [NetworkInterface] {
        let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []
        return interfaces.compactMap { interface in
            guard let bsdName = SCNetworkInterfaceGetBSDName(interface) as String? else { return nil }
            let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? ?? bsdName
            return NetworkInterface(bsdName: bsdName, displayName: displayName)
        }
    }
}
