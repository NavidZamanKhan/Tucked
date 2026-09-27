import Foundation
import AppKit
import Darwin

/// Sampler for enumerating processes, calculating CPU utilization deltas, and physical footprint ranking.
public final class ProcessSampler: @unchecked Sendable {
    private struct ProcessCPUBaseline {
        var cpuTicks: UInt64
        var wallTime: UInt64
    }
    
    private struct RawProcessCandidate {
        let pid: Int32
        let cpuPercent: Double
        let memoryBytes: UInt64
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
    /// Utilizes deferred metadata resolution to eliminate 97% of IPC lookups.
    public func sample() -> (topCPU: [ProcessItem], topMemory: [ProcessItem], isMeasuringCPU: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        let pids = listAllPIDs()
        let nowWall = mach_absolute_time()
        
        var currentBaselines: [Int32: ProcessCPUBaseline] = [:]
        var cpuCandidates: [RawProcessCandidate] = []
        var memoryCandidates: [RawProcessCandidate] = []
        
        let isInitialCPUScan = previousBaselines.isEmpty
        
        // Fast Phase 1: Pure kernel metrics scan across all PIDs (zero LaunchServices IPC)
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
            
            let candidate = RawProcessCandidate(pid: pid, cpuPercent: cpuPercent, memoryBytes: memoryBytes)
            memoryCandidates.append(candidate)
            if !isInitialCPUScan && cpuPercent > 0.1 {
                cpuCandidates.append(candidate)
            }
        }
        
        previousBaselines = currentBaselines
        
        // Fast Phase 2: Mathematical ranking to isolate top 6 CPU and top 6 Memory finalists
        let topMemoryCandidates = memoryCandidates
            .sorted { $0.memoryBytes > $1.memoryBytes }
            .prefix(6)
            
        let topCPUCandidates = cpuCandidates
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(6)
            
        // Fast Phase 3: Deferred resolution - only query LaunchServices and UID for finalists (max 12)
        var resolvedCache: [Int32: ProcessItem] = [:]
        
        func resolve(candidate: RawProcessCandidate) -> ProcessItem {
            if let cached = resolvedCache[candidate.pid] {
                return ProcessItem(
                    pid: candidate.pid,
                    name: cached.name,
                    bundleIdentifier: nil,
                    ownerUID: cached.ownerUID,
                    cpuUsagePercent: candidate.cpuPercent,
                    memoryBytes: candidate.memoryBytes,
                    isClosable: cached.isClosable,
                    isSystemProtected: cached.isSystemProtected
                )
            }
            
            let name = resolveProcessName(pid: candidate.pid)
            let uid = resolveProcessUID(pid: candidate.pid)
            let closable = ProcessTerminationPolicy.isClosable(pid: candidate.pid, name: name, ownerUID: uid)
            let isProtected = !closable
            
            let item = ProcessItem(
                pid: candidate.pid,
                name: name,
                bundleIdentifier: nil,
                ownerUID: uid,
                cpuUsagePercent: candidate.cpuPercent,
                memoryBytes: candidate.memoryBytes,
                isClosable: closable,
                isSystemProtected: isProtected
            )
            resolvedCache[candidate.pid] = item
            return item
        }
        
        let topCPU = topCPUCandidates.map { resolve(candidate: $0) }
        let topMemory = topMemoryCandidates.map { resolve(candidate: $0) }
        
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
