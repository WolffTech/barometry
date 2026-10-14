// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Darwin
import Foundation

struct MemorySampler {
    private let host = mach_host_self()
    private let pageSize = UInt64(getpagesize())
    private let total = ByteCount(bytes: Int64(clamping: ProcessInfo.processInfo.physicalMemory))

    func sample() throws -> MemorySample {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            throw KernelError(call: "host_statistics64", code: result)
        }

        let pages = VMPageCounts(
            internal: UInt64(stats.internal_page_count),
            purgeable: UInt64(stats.purgeable_count),
            external: UInt64(stats.external_page_count),
            wired: UInt64(stats.wire_count),
            compressor: UInt64(stats.compressor_page_count)
        )
        let pressure = MemoryPressure(
            kernelLevel: Sysctl.integer("kern.memorystatus_vm_pressure_level") ?? 1,
            availableLevel: Sysctl.integer("kern.memorystatus_level") ?? 100
        )
        let swap = Sysctl.value("vm.swapusage", empty: xsw_usage())
        return MemorySample(
            pages: pages,
            pageSize: pageSize,
            total: total,
            pressure: pressure,
            swapUsed: swap.map { ByteCount(bytes: Int64(clamping: $0.xsu_used)) }
        )
    }
}
