import Foundation
import Darwin

/// Sampler for physical memory, swap, and compression using Mach VM statistics.
public final class MemorySampler: @unchecked Sendable {
    public let physicalMemoryBytes: UInt64
    private let pageSize: UInt64
    
    public init() {
        self.physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        self.pageSize = size > 0 ? UInt64(size) : 16384
    }
    
    public func sample(pressureStatus: MemoryHealthStatus = .normal) -> MemoryUsageSnapshot {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            TuckedLog.memory.error("Failed to read host_statistics64: \(result)")
            return MemoryUsageSnapshot(
                usedBytes: 0,
                totalPhysicalBytes: physicalMemoryBytes,
                swapBytes: 0,
                compressedBytes: 0,
                usedPercentage: 0,
                status: pressureStatus
            )
        }
        
        let active = Int64(vmStats.active_count)
        let inactive = Int64(vmStats.inactive_count)
        let speculative = Int64(vmStats.speculative_count)
        let wired = Int64(vmStats.wire_count)
        let compressor = Int64(vmStats.compressor_page_count)
        let purgeable = Int64(vmStats.purgeable_count)
        let external = Int64(vmStats.external_page_count)
        
        // Canonical approximation: P * (active + inactive + speculative + wired + compressor - purgeable - external)
        let usedPagesRaw = active + inactive + speculative + wired + compressor - purgeable - external
        let usedPages = max(0, usedPagesRaw)
        let usedBytes = UInt64(usedPages) * pageSize
        
        let compressedBytes = UInt64(max(0, compressor)) * pageSize
        let swapBytes = readSwapUsedBytes()
        
        let percentage = physicalMemoryBytes > 0
            ? min(100.0, max(0.0, Double(usedBytes) / Double(physicalMemoryBytes) * 100.0))
            : 0.0
            
        return MemoryUsageSnapshot(
            usedBytes: usedBytes,
            totalPhysicalBytes: physicalMemoryBytes,
            swapBytes: swapBytes,
            compressedBytes: compressedBytes,
            usedPercentage: percentage,
            status: pressureStatus
        )
    }
    
    private func readSwapUsedBytes() -> UInt64 {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &swap, &size, nil, 0)
        guard result == 0 else {
            return 0
        }
        return swap.xsu_used
    }
}
