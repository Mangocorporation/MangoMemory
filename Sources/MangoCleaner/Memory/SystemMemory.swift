import Darwin
import Foundation
import MangoCleanerKit

/// Reads memory from the kernel. Read-only and safe to call from any thread.
nonisolated enum SystemMemory {
    static func stats() -> MemoryStats? {
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let counts = VMCounts(
            active: UInt64(info.active_count),
            inactive: UInt64(info.inactive_count),
            speculative: UInt64(info.speculative_count),
            wired: UInt64(info.wire_count),
            compressed: UInt64(info.compressor_page_count),
            purgeable: UInt64(info.purgeable_count),
            external: UInt64(info.external_page_count)
        )
        return MemoryStats(
            counts: counts,
            pageSize: UInt64(getpagesize()),
            total: ProcessInfo.processInfo.physicalMemory,
            swapUsed: swapUsed(),
            kernelLevel: sysctlInt32("kern.memorystatus_vm_pressure_level") ?? 1,
            availablePercent: sysctlInt32("kern.memorystatus_level") ?? 100
        )
    }

    static func swapUsed() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return usage.xsu_used
    }

    private static func sysctlInt32(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
    }

    /// Footprint (what Activity Monitor calls Memory) of every process this
    /// user can read, with the process responsible for it.
    static func processes() -> [ProcessSample] {
        let capacity = Int(proc_listallpids(nil, 0)) + 64
        var pids = [pid_t](repeating: 0, count: capacity)
        let found = Int(proc_listallpids(&pids, Int32(capacity * MemoryLayout<pid_t>.size)))
        guard found > 0 else { return [] }
        return pids.prefix(min(found, capacity)).compactMap { pid in
            guard pid > 0, let footprint = footprint(of: pid) else { return nil }
            let owner = responsibility_get_pid_responsible_for_pid(pid)
            return ProcessSample(pid: pid, responsiblePID: owner > 0 ? owner : pid, footprint: footprint)
        }
    }

    private static func footprint(of pid: pid_t) -> UInt64? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? info.ri_phys_footprint : nil
    }
}

/// Private but stable since macOS 10.14; Activity Monitor groups processes the same way.
@_silgen_name("responsibility_get_pid_responsible_for_pid")
nonisolated private func responsibility_get_pid_responsible_for_pid(_ pid: pid_t) -> pid_t
