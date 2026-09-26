import Foundation

public struct HistorySample: Sendable {
    public let cpu: Double
    public let memory: Double
    public let rxBytes: Double
    public let txBytes: Double
    public let timestamp: Date
    
    public init(cpu: Double, memory: Double, rxBytes: Double, txBytes: Double, timestamp: Date = Date()) {
        self.cpu = cpu
        self.memory = memory
        self.rxBytes = rxBytes
        self.txBytes = txBytes
        self.timestamp = timestamp
    }
}

/// Fixed-capacity ring buffer for rolling metric history (~90 seconds at 1 Hz).
public final class HistoryStore: @unchecked Sendable {
    public let capacity: Int
    private var buffer: [HistorySample?]
    private var headIndex: Int = 0
    private var count: Int = 0
    private let lock = NSLock()
    
    public init(capacity: Int = 90) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    public func append(sample: HistorySample) {
        lock.lock()
        defer { lock.unlock() }
        
        let insertIndex = (headIndex + count) % capacity
        buffer[insertIndex] = sample
        if count < capacity {
            count += 1
        } else {
            headIndex = (headIndex + 1) % capacity
        }
    }
    
    public func append(cpu: Double, memory: Double, rx: Double, tx: Double, timestamp: Date = Date()) {
        let sample = HistorySample(cpu: cpu, memory: memory, rxBytes: rx, txBytes: tx, timestamp: timestamp)
        append(sample: sample)
    }
    
    public func samples() -> [HistorySample] {
        lock.lock()
        defer { lock.unlock() }
        
        var result = [HistorySample]()
        result.reserveCapacity(count)
        for i in 0..<count {
            let index = (headIndex + i) % capacity
            if let item = buffer[index] {
                result.append(item)
            }
        }
        return result
    }
    
    public func cpuHistory() -> [Double] {
        return samples().map { $0.cpu }
    }
    
    public func memoryHistory() -> [Double] {
        return samples().map { $0.memory }
    }
    
    public func networkRxHistory() -> [Double] {
        return samples().map { $0.rxBytes }
    }
    
    public func networkTxHistory() -> [Double] {
        return samples().map { $0.txBytes }
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer = Array(repeating: nil, count: capacity)
        headIndex = 0
        count = 0
    }
}
