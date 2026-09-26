import Foundation
import Darwin

/// Monitors system memory pressure via DispatchSource and sysctl reconciliation.
public final class MemoryPressureMonitor: @unchecked Sendable {
    private var source: (any DispatchSourceMemoryPressure)?
    private let queue = DispatchQueue(label: "ai.mpiv.Tucked.MemoryPressure", qos: .utility)
    private var currentStatus: MemoryHealthStatus = .normal
    private let lock = NSLock()
    
    public init() {}
    
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        
        // Initial reconciliation
        currentStatus = readPressureSysctl() ?? .normal
        
        let pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: queue
        )
        
        pressureSource.setEventHandler { [weak self] in
            guard let self = self else { return }
            let data = pressureSource.data
            var newStatus: MemoryHealthStatus = .normal
            if data.contains(.critical) {
                newStatus = .critical
            } else if data.contains(.warning) {
                newStatus = .heavy
            } else {
                newStatus = .normal
            }
            
            self.lock.lock()
            self.currentStatus = newStatus
            self.lock.unlock()
            
            TuckedLog.memory.debug("Memory pressure event received: \(newStatus.rawValue)")
        }
        
        pressureSource.resume()
        self.source = pressureSource
    }
    
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        source?.cancel()
        source = nil
    }
    
    public var status: MemoryHealthStatus {
        lock.lock()
        defer { lock.unlock() }
        return currentStatus
    }
    
    public func reconcile() {
        if let direct = readPressureSysctl() {
            lock.lock()
            currentStatus = direct
            lock.unlock()
        }
    }
    
    private func readPressureSysctl() -> MemoryHealthStatus? {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        guard result == 0 else { return nil }
        
        switch level {
        case 1:
            return .normal
        case 2:
            return .heavy
        case 4:
            return .critical
        default:
            return .normal
        }
    }
}
