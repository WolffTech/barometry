// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// Minimal binding to the private libIOReport, which publishes per-cluster CPU and GPU
/// DVFS state residency. Functions are looked up at runtime so a missing symbol degrades
/// to "no frequency data" instead of a launch failure.
final class IOReportSubscription {
    struct Channel {
        let name: String
        /// State names and time spent in each over the interval, in IOReport order.
        let states: [(name: String, residency: Int64)]
    }

    private typealias CopyChannelsInGroup = @convention(c) (CFString?, CFString?, UInt64, UInt64, UInt64) -> Unmanaged<CFMutableDictionary>?
    private typealias CreateSubscription = @convention(c) (UnsafeMutableRawPointer?, CFMutableDictionary, UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>, UInt64, CFTypeRef?) -> Unmanaged<CFTypeRef>?
    private typealias CreateSamples = @convention(c) (CFTypeRef, CFMutableDictionary, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias CreateSamplesDelta = @convention(c) (CFDictionary, CFDictionary, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias ChannelString = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias StateCount = @convention(c) (CFDictionary) -> Int32
    private typealias StateName = @convention(c) (CFDictionary, Int32) -> Unmanaged<CFString>?
    private typealias StateResidency = @convention(c) (CFDictionary, Int32) -> Int64

    private let createSamples: CreateSamples
    private let createSamplesDelta: CreateSamplesDelta
    private let channelName: ChannelString
    private let stateCount: StateCount
    private let stateName: StateName
    private let stateResidency: StateResidency

    private let subscription: CFTypeRef
    private let subscribedChannels: CFMutableDictionary
    private var previous: CFDictionary?

    /// Subscribes to the given (group, subgroup) pairs, such as ("CPU Stats", "CPU Complex Performance States").
    init?(channels groups: [(group: String, subgroup: String)]) {
        guard let library = dlopen("/usr/lib/libIOReport.dylib", RTLD_NOW) else { return nil }
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            dlsym(library, name).map { unsafeBitCast($0, to: type) }
        }
        guard let copyChannelsInGroup = symbol("IOReportCopyChannelsInGroup", as: CopyChannelsInGroup.self),
              let createSubscription = symbol("IOReportCreateSubscription", as: CreateSubscription.self),
              let createSamples = symbol("IOReportCreateSamples", as: CreateSamples.self),
              let createSamplesDelta = symbol("IOReportCreateSamplesDelta", as: CreateSamplesDelta.self),
              let channelName = symbol("IOReportChannelGetChannelName", as: ChannelString.self),
              let stateCount = symbol("IOReportStateGetCount", as: StateCount.self),
              let stateName = symbol("IOReportStateGetNameForIndex", as: StateName.self),
              let stateResidency = symbol("IOReportStateGetResidency", as: StateResidency.self)
        else { return nil }

        self.createSamples = createSamples
        self.createSamplesDelta = createSamplesDelta
        self.channelName = channelName
        self.stateCount = stateCount
        self.stateName = stateName
        self.stateResidency = stateResidency

        // Merge every requested group into one channel dictionary.
        var merged: NSMutableDictionary?
        for (group, subgroup) in groups {
            guard let channels = copyChannelsInGroup(group as CFString, subgroup as CFString, 0, 0, 0)?.takeRetainedValue() as NSMutableDictionary? else { continue }
            if let merged, let existing = merged["IOReportChannels"] as? NSMutableArray, let added = channels["IOReportChannels"] as? [Any] {
                existing.addObjects(from: added)
            } else {
                merged = channels
            }
        }
        guard let merged else { return nil }

        var subscribed: Unmanaged<CFMutableDictionary>?
        guard let subscription = createSubscription(nil, merged as CFMutableDictionary, &subscribed, 0, nil)?.takeRetainedValue(),
              let subscribed = subscribed?.takeRetainedValue()
        else { return nil }
        self.subscription = subscription
        self.subscribedChannels = subscribed
    }

    /// Channel residency since the previous call. Empty on the first call.
    func sample() -> [Channel] {
        guard let current = createSamples(subscription, subscribedChannels, nil)?.takeRetainedValue() else { return [] }
        defer { previous = current }
        guard let previous,
              let delta = createSamplesDelta(previous, current, nil)?.takeRetainedValue() as NSDictionary?,
              let channels = delta["IOReportChannels"] as? [CFDictionary]
        else { return [] }

        return channels.map { channel in
            let states = (0..<stateCount(channel)).map { index in
                (name: stateName(channel, index)?.takeUnretainedValue() as String? ?? "", residency: stateResidency(channel, index))
            }
            return Channel(name: channelName(channel)?.takeUnretainedValue() as String? ?? "", states: states)
        }
    }
}
