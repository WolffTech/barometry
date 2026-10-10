import Darwin
import SystemConfiguration

/// Measures traffic on a chosen interface, or on the primary one (carrying the default route).
struct NetworkSampler {
    private let store = SCDynamicStoreCreate(nil, "Barometry" as CFString, nil, nil)
    private var tracker = NetworkRateTracker()

    /// Returns nil on the first call, after the interface changes, and while it's offline.
    mutating func sample(interface preferred: String?) -> NetworkSample? {
        guard let interface = preferred ?? primaryInterface(), let counters = Self.counters(for: interface) else {
            tracker.reset()
            return nil
        }
        return tracker.update(interface: interface, counters: counters, at: .now)
    }

    private func primaryInterface() -> String? {
        for key in ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"] {
            if let global = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
               let interface = global["PrimaryInterface"] as? String {
                return interface
            }
        }
        return nil
    }

    private static func counters(for interface: String) -> NetworkCounters? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }

        // The AF_LINK entry for an interface carries its if_data counters.
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let address = entry.pointee
            guard let socketAddress = address.ifa_addr,
                  socketAddress.pointee.sa_family == UInt8(AF_LINK),
                  String(cString: address.ifa_name) == interface,
                  let data = address.ifa_data?.assumingMemoryBound(to: if_data.self).pointee
            else { continue }
            return NetworkCounters(received: data.ifi_ibytes, sent: data.ifi_obytes)
        }
        return nil
    }
}
