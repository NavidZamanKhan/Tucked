import Foundation
import Darwin

/// Sampler for host-wide CPU utilization using Mach host_statistics.
public final class CPUSampler: @unchecked Sendable {
    private var previousUserTicks: UInt32 = 0
    private var previousNiceTicks: UInt32 = 0
    private var previousSystemTicks: UInt32 = 0
    private var previousIdleTicks: UInt32 = 0
    private var hasBaseline: Bool = false
    
    // Hysteresis tracking for status pill
    private var currentStatus: CPUHealthStatus = .normal
    private var heavyThresholdStart: Date?
    private var criticalThresholdStart: Date?
    private var recoveryStart: Date?
    
    public init() {}
    
    public func resetBaseline() {
        hasBaseline = false
        heavyThresholdStart = nil
        criticalThresholdStart = nil
        recoveryStart = nil
    }
    
    public func sample() -> CPUUsageSnapshot {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            TuckedLog.cpu.error("Failed to read host_statistics: \(result)")
            return CPUUsageSnapshot(totalUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 100, status: .normal)
        }
        
        let currentUser = cpuLoad.cpu_ticks.0
        let currentNice = cpuLoad.cpu_ticks.1
        let currentSystem = cpuLoad.cpu_ticks.2
        let currentIdle = cpuLoad.cpu_ticks.3
        
        guard hasBaseline else {
            previousUserTicks = currentUser
            previousNiceTicks = currentNice
            previousSystemTicks = currentSystem
            previousIdleTicks = currentIdle
            hasBaseline = true
            return CPUUsageSnapshot(totalUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 100, status: .normal)
        }
        
        // 32-bit unsigned modular difference handles wraps safely
        let userDiff = currentUser &- previousUserTicks
        let niceDiff = currentNice &- previousNiceTicks
        let systemDiff = currentSystem &- previousSystemTicks
        let idleDiff = currentIdle &- previousIdleTicks
        
        previousUserTicks = currentUser
        previousNiceTicks = currentNice
        previousSystemTicks = currentSystem
        previousIdleTicks = currentIdle
        
        let totalTicks = UInt64(userDiff) + UInt64(niceDiff) + UInt64(systemDiff) + UInt64(idleDiff)
        guard totalTicks > 0 else {
            return CPUUsageSnapshot(totalUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 100, status: currentStatus)
        }
        
        let userPercent = Double(userDiff + niceDiff) / Double(totalTicks) * 100.0
        let systemPercent = Double(systemDiff) / Double(totalTicks) * 100.0
        let idlePercent = Double(idleDiff) / Double(totalTicks) * 100.0
        let totalPercent = Double(userDiff + niceDiff + systemDiff) / Double(totalTicks) * 100.0
        
        let evaluatedStatus = evaluateStatus(totalUsage: totalPercent, now: Date())
        
        return CPUUsageSnapshot(
            totalUsage: totalPercent,
            userUsage: userPercent,
            systemUsage: systemPercent,
            idleUsage: idlePercent,
            status: evaluatedStatus
        )
    }
    
    private func evaluateStatus(totalUsage: Double, now: Date) -> CPUHealthStatus {
        switch currentStatus {
        case .normal:
            if totalUsage >= 90.0 {
                if let start = criticalThresholdStart {
                    if now.timeIntervalSince(start) >= 5.0 {
                        currentStatus = .critical
                        criticalThresholdStart = nil
                        heavyThresholdStart = nil
                    }
                } else {
                    criticalThresholdStart = now
                }
            } else if totalUsage >= 70.0 {
                criticalThresholdStart = nil
                if let start = heavyThresholdStart {
                    if now.timeIntervalSince(start) >= 4.0 {
                        currentStatus = .heavy
                        heavyThresholdStart = nil
                    }
                } else {
                    heavyThresholdStart = now
                }
            } else {
                heavyThresholdStart = nil
                criticalThresholdStart = nil
            }
            
        case .heavy:
            if totalUsage >= 90.0 {
                if let start = criticalThresholdStart {
                    if now.timeIntervalSince(start) >= 5.0 {
                        currentStatus = .critical
                        criticalThresholdStart = nil
                        recoveryStart = nil
                    }
                } else {
                    criticalThresholdStart = now
                }
            } else if totalUsage < 65.0 {
                criticalThresholdStart = nil
                if let start = recoveryStart {
                    if now.timeIntervalSince(start) >= 4.0 {
                        currentStatus = .normal
                        recoveryStart = nil
                    }
                } else {
                    recoveryStart = now
                }
            } else {
                criticalThresholdStart = nil
                recoveryStart = nil
            }
            
        case .critical:
            if totalUsage < 85.0 {
                if let start = recoveryStart {
                    if now.timeIntervalSince(start) >= 5.0 {
                        currentStatus = totalUsage < 65.0 ? .normal : .heavy
                        recoveryStart = nil
                    }
                } else {
                    recoveryStart = now
                }
            } else {
                recoveryStart = nil
            }
        }
        
        return currentStatus
    }
}
