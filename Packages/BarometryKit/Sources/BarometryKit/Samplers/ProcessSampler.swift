// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Darwin
import Foundation

/// Reads every process the user can see with `proc_pid_rusage` and groups them by the app
/// responsible for them. A full pass takes a few milliseconds, so the monitor runs it only
/// while process lists are on screen.
struct ProcessSampler {
    private var tracker = ProcessUsageTracker()
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Returns nil on the first call, since usage needs two readings.
    mutating func sample() -> TopApps? {
        let readings = Self.processIDs().compactMap(reading)
        return tracker.update(readings, at: .now) { owner, member in
            AppIdentity(executablePath: Self.path(owner) ?? Self.path(member) ?? Self.name(member))
        }
    }

    mutating func reset() {
        tracker.reset()
    }

    private static func processIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        // Leave room for processes started since counting.
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        return Array(pids.prefix(Int(max(filled, 0))))
    }

    /// Nil for processes owned by other users, which need root to read.
    private func reading(_ pid: pid_t) -> ProcessReading? {
        var info = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
            }
        }
        guard result == 0 else { return nil }
        // CPU times are in Mach absolute time units, which aren't nanoseconds on Apple silicon.
        let cpuTicks = info.ri_user_time + info.ri_system_time
        return ProcessReading(
            pid: pid,
            owner: Self.responsibleProcess(pid) ?? pid,
            startTime: info.ri_proc_start_abstime,
            cpuTime: cpuTicks * UInt64(timebase.numer) / UInt64(timebase.denom),
            energy: info.ri_energy_nj,
            memory: info.ri_phys_footprint
        )
    }

    /// Looked up at runtime, since it's private to macOS. It's what Activity Monitor uses to
    /// count helpers, such as Safari's WebContent processes, toward their app.
    private static let responsibilityLookup: (@convention(c) (pid_t) -> pid_t)? = {
        // -2 is RTLD_DEFAULT, which Swift doesn't import.
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else {
            return nil
        }
        return unsafeBitCast(symbol, to: (@convention(c) (pid_t) -> pid_t).self)
    }()

    private static func responsibleProcess(_ pid: pid_t) -> pid_t? {
        guard let owner = responsibilityLookup?(pid), owner > 0 else { return nil }
        return owner
    }

    private static func path(_ pid: pid_t) -> String? {
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return nil }
        return String(decoding: path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// The short name from `proc_name`, for when the path can't be read.
    private static func name(_ pid: pid_t) -> String {
        var name = [CChar](repeating: 0, count: 64)
        proc_name(pid, &name, UInt32(name.count))
        return String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
