import Foundation
import Network

/// Diagnostics service measuring connection latency and jitter via TCP setup to public resolver.
public final class NetworkDiagnosticsService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ai.mpiv.Tucked.NetworkDiagnostics", qos: .utility)
    private var activeConnection: NWConnection?
    private var latencyHistory: [Double] = []
    private let maxHistory = 10
    private let lock = NSLock()
    private var isCancelled: Bool = false
    private var isCompleted: Bool = false
    
    public init() {}
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = true
        activeConnection?.cancel()
        activeConnection = nil
        latencyHistory.removeAll()
    }
    
    public func probe(completion: @escaping @Sendable (Double?, Double?, NetworkHealthStatus) -> Void) {
        lock.lock()
        isCancelled = false
        isCompleted = false
        activeConnection?.cancel()
        
        let endpoint = NWEndpoint.hostPort(host: "1.1.1.1", port: 443)
        let tcpParameters = NWParameters.tcp
        tcpParameters.preferNoProxies = true
        
        let connection = NWConnection(to: endpoint, using: tcpParameters)
        self.activeConnection = connection
        lock.unlock()
        
        let startTime = mach_absolute_time()
        
        // Timeout after 1.5 seconds
        queue.asyncAfter(deadline: .now() + 1.5) { [weak self, weak connection] in
            guard let self = self, let connection = connection else { return }
            self.lock.lock()
            guard !self.isCompleted, !self.isCancelled, self.activeConnection === connection else {
                self.lock.unlock()
                return
            }
            self.isCompleted = true
            connection.cancel()
            self.activeConnection = nil
            self.lock.unlock()
            
            completion(nil, nil, .poor)
        }
        
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self = self, let connection = connection else { return }
            
            switch state {
            case .ready:
                self.lock.lock()
                guard !self.isCompleted, !self.isCancelled else {
                    self.lock.unlock()
                    return
                }
                self.isCompleted = true
                self.activeConnection = nil
                self.lock.unlock()
                
                let endTime = mach_absolute_time()
                var timebase = mach_timebase_info()
                mach_timebase_info(&timebase)
                
                let elapsedTicks = endTime > startTime ? endTime - startTime : 0
                let elapsedNs = elapsedTicks * UInt64(timebase.numer) / UInt64(timebase.denom)
                let elapsedMs = Double(elapsedNs) / 1_000_000.0
                
                connection.cancel()
                
                self.lock.lock()
                self.latencyHistory.append(elapsedMs)
                if self.latencyHistory.count > self.maxHistory {
                    self.latencyHistory.removeFirst()
                }
                let currentHistory = self.latencyHistory
                self.lock.unlock()
                
                let (jitter, health) = self.calculateJitterAndHealth(history: currentHistory, latestLatency: elapsedMs)
                completion(elapsedMs, jitter, health)
                
            case .failed:
                self.lock.lock()
                guard !self.isCompleted, !self.isCancelled else {
                    self.lock.unlock()
                    return
                }
                self.isCompleted = true
                self.activeConnection = nil
                self.lock.unlock()
                
                connection.cancel()
                completion(nil, nil, .poor)
                
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func calculateJitterAndHealth(history: [Double], latestLatency: Double) -> (Double?, NetworkHealthStatus) {
        guard history.count >= 2 else {
            return (nil, .checking)
        }
        
        // Mean absolute successive difference
        var sumDiff: Double = 0
        for i in 1..<history.count {
            sumDiff += abs(history[i] - history[i - 1])
        }
        let jitter = sumDiff / Double(history.count - 1)
        
        let health: NetworkHealthStatus
        if history.count < 3 {
            health = .checking
        } else if latestLatency < 100 && jitter < 30 {
            health = .stable
        } else if latestLatency > 300 || jitter > 100 {
            health = .poor
        } else {
            health = .degraded
        }
        
        return (jitter, health)
    }
}
