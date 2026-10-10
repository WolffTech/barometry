import Darwin

struct CPUSampler {
    private let host = mach_host_self()
    private let kinds = CoreTopology.current()
    private var previous: [CPUTicks]?

    /// Returns nil on the first call, since load needs two readings.
    mutating func sample() throws -> CPUSample? {
        let current = try readTicks()
        defer { previous = current }
        guard let previous else { return nil }
        return CPUSample(from: previous, to: current, kinds: kinds)
    }

    private func readTicks() throws -> [CPUTicks] {
        var cpuCount = natural_t()
        var info: processor_info_array_t?
        var infoCount = mach_msg_type_number_t()
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else {
            throw KernelError(call: "host_processor_info", code: result)
        }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        return (0..<Int(cpuCount)).map { cpu in
            func ticks(_ state: Int32) -> UInt32 {
                UInt32(bitPattern: info[cpu * Int(CPU_STATE_MAX) + Int(state)])
            }
            return CPUTicks(
                user: ticks(CPU_STATE_USER),
                system: ticks(CPU_STATE_SYSTEM),
                idle: ticks(CPU_STATE_IDLE),
                nice: ticks(CPU_STATE_NICE)
            )
        }
    }
}
