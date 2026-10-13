import Darwin

/// Reads every process the user can see with `proc_pid_rusage`. A full pass takes a few
/// milliseconds, so the monitor runs it only while process lists are on screen.
struct ProcessSampler {
    private var tracker = ProcessUsageTracker()
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Returns nil on the first call, since usage needs two readings.
    mutating func sample() -> TopProcesses? {
        let readings = Self.processIDs().compactMap(reading)
        return tracker.update(readings, at: .now, name: Self.name)
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
            startTime: info.ri_proc_start_abstime,
            cpuTime: cpuTicks * UInt64(timebase.numer) / UInt64(timebase.denom),
            energy: info.ri_energy_nj,
            memory: info.ri_phys_footprint
        )
    }

    /// The executable's file name, such as "Google Chrome Helper (Renderer)", which
    /// `proc_name` truncates.
    private static func name(_ pid: pid_t) -> String {
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        if proc_pidpath(pid, &path, UInt32(path.count)) > 0 {
            let fullPath = String(decoding: path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            if let last = fullPath.split(separator: "/").last {
                return String(last)
            }
        }
        var name = [CChar](repeating: 0, count: 64)
        proc_name(pid, &name, UInt32(name.count))
        return String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
