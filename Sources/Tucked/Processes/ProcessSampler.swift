import Foundation
import AppKit
import Darwin

/// Sampler for enumerating processes, calculating CPU utilization deltas, and physical footprint ranking.
public final class ProcessSampler: @unchecked Sendable {
    private struct ProcessCPUBaseline {
        var cpuTicks: UInt64
        var wallTime: UInt64
    }
    
    private var previousBaselines: [Int32: ProcessCPUBaseline] = [:]
    private var timebaseInfo = mach_timebase_info()
    private let lock = NSLock()
    
    public init() {
        mach_timebase_info(&timebaseInfo)
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        previousBaselines.removeAll()
    }
    
    /// Performs a full scan of system processes, returning top CPU and top Memory lists.
    public func sample() -> (topCPU: [ProcessItem], topMemory: [ProcessItem], isMeasuringCPU: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        let pids = listAllPIDs()
        let nowWall = mach_absolute_time()
        
        var currentBaselines: [Int32: ProcessCPUBaseline] = [:]
        var cpuCandidates: [ProcessItem] = []
        var memoryCandidates: [ProcessItem] = []
        
        let isInitialCPUScan = previousBaselines.isEmpty
        
        for pid in pids where pid > 0 {
            var rusage = rusage_info_v2()
            let result = withUnsafeMutablePointer(to: &rusage) { ptr in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rusagePtr in
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, rusagePtr)
                }
            }
            
            guard result == 0 else { continue }
            
            let cpuTicks = rusage.ri_user_time + rusage.ri_system_time
            let memoryBytes = rusage.ri_phys_footprint
            
            currentBaselines[pid] = ProcessCPUBaseline(cpuTicks: cpuTicks, wallTime: nowWall)
            
            // Calculate CPU percentage if previous baseline exists
            var cpuPercent = 0.0
            if let prev = previousBaselines[pid] {
                let wallDelta = nowWall > prev.wallTime ? nowWall - prev.wallTime : 0
                let cpuDelta = cpuTicks >= prev.cpuTicks ? cpuTicks - prev.cpuTicks : 0
                if wallDelta > 0 {
                    // Activity Monitor convention: 100% = 1 core fully loaded
                    cpuPercent = (Double(cpuDelta) / Double(wallDelta)) * 100.0
                }
            }
            
            let name = resolveProcessName(pid: pid)
            let uid = resolveProcessUID(pid: pid)
            let closable = ProcessTerminationPolicy.isClosable(pid: pid, name: name, ownerUID: uid)
            let isProtected = !closable
            
            let item = ProcessItem(
                pid: pid,
                name: name,
                bundleIdentifier: nil,
                ownerUID: uid,
                cpuUsagePercent: cpuPercent,
                memoryBytes: memoryBytes,
                isClosable: closable,
                isSystemProtected: isProtected
            )
            
            memoryCandidates.append(item)
            if !isInitialCPUScan && cpuPercent > 0.1 {
                cpuCandidates.append(item)
            }
        }
        
        previousBaselines = currentBaselines
        
        // Sort Top Memory by physical footprint descending
        let topMemory = memoryCandidates
            .sorted { $0.memoryBytes > $1.memoryBytes }
            .prefix(6)
            .map { $0 }
            
        // Sort Top CPU by CPU percentage descending
        let topCPU = cpuCandidates
            .sorted { $0.cpuUsagePercent > $1.cpuUsagePercent }
            .prefix(6)
            .map { $0 }
            
        return (topCPU: topCPU, topMemory: topMemory, isMeasuringCPU: isInitialCPUScan)
    }
    
    private func listAllPIDs() -> [Int32] {
        let estimatedCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard estimatedCount > 0 else { return [] }
        
        var pids = [Int32](repeating: 0, count: Int(estimatedCount) / MemoryLayout<Int32>.size + 64)
        let actualBytes = proc_listpids(
            UInt32(PROC_ALL_PIDS),
            0,
            &pids,
            Int32(pids.count * MemoryLayout<Int32>.size)
        )
        guard actualBytes > 0 else { return [] }
        
        let actualCount = Int(actualBytes) / MemoryLayout<Int32>.size
        return Array(pids.prefix(actualCount))
    }
    
    private func resolveProcessName(pid: Int32) -> String {
        // Fast path: check NSRunningApplication for GUI apps
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName, !name.isEmpty {
            return name
        }
        
        // Fallback: proc_name
        var nameBuffer = [CChar](repeating: 0, count: 256)
        let nameLen = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if nameLen > 0 {
            let actualBytes = nameBuffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
            return String(decoding: actualBytes, as: UTF8.self)
        }
        
        return "Process \(pid)"
    }
    
    private func resolveProcessUID(pid: Int32) -> uid_t {
        var bsdInfo = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let bytesRead = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, size)
        if bytesRead == size {
            return bsdInfo.pbi_uid
        }
        return getuid()
    }
}
