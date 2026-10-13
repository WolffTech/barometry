import Darwin
import SystemConfiguration

/// Measures traffic on a chosen interface, or on the primary one (carrying the default route).
struct NetworkSampler {
    private let store = SCDynamicStoreCreate(nil, "Barometry" as CFString, nil, nil)
    private var tracker = NetworkRateTracker()

    /// Returns nil on the first call, after the interface changes, and while it's offline.
    mutating func sample(interface preferred: String?) -> NetworkSample? {
        guard let interface = preferred ?? primaryInterface(), let reading = Self.read(interface) else {
            tracker.reset()
            return nil
        }
        return tracker.update(interface: interface, counters: reading.counters, address: reading.address, at: .now)
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

    /// Nil if the interface has no counters, such as when it's gone.
    private static func read(_ interface: String) -> (counters: NetworkCounters, address: String?)? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }

        var counters: NetworkCounters?
        var ipv4: String?
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let address = entry.pointee
            guard let socketAddress = address.ifa_addr, String(cString: address.ifa_name) == interface else { continue }
            switch Int32(socketAddress.pointee.sa_family) {
            case AF_LINK:
                // The AF_LINK entry for an interface carries its if_data counters.
                if let data = address.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                    counters = NetworkCounters(received: data.ifi_ibytes, sent: data.ifi_obytes)
                }
            case AF_INET where ipv4 == nil:
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(socketAddress, socklen_t(socketAddress.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    ipv4 = String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
                }
            default:
                break
            }
        }
        return counters.map { ($0, ipv4) }
    }
}
