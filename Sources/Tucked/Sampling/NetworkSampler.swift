import Foundation
import Darwin

/// Sampler for physical network throughput using 64-bit routing sysctl counters.
public final class NetworkSampler: @unchecked Sendable {
    private struct InterfaceBaseline {
        var rxBytes: UInt64
        var txBytes: UInt64
    }
    
    private var baselines: [String: InterfaceBaseline] = [:]
    private var previousTimestamp: Date?
    private var cumulativeRxBytes: UInt64 = 0
    private var cumulativeTxBytes: UInt64 = 0
    private let lock = NSLock()
    
    public init() {}
    
    public func resetBaseline() {
        lock.lock()
        defer { lock.unlock() }
        baselines.removeAll()
        previousTimestamp = nil
    }
    
    public func resetTotals() {
        lock.lock()
        defer { lock.unlock() }
        cumulativeRxBytes = 0
        cumulativeTxBytes = 0
    }
    
    public func sample() -> NetworkUsageSnapshot {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let currentCounters = readInterfaceCounters()
        
        guard let prevTime = previousTimestamp, !baselines.isEmpty else {
            baselines = currentCounters
            previousTimestamp = now
            return NetworkUsageSnapshot(
                rxBytesPerSecond: 0,
                txBytesPerSecond: 0,
                status: .stable,
                totalRxBytes: cumulativeRxBytes,
                totalTxBytes: cumulativeTxBytes
            )
        }
        
        let elapsed = now.timeIntervalSince(prevTime)
        guard elapsed > 0.05 else {
            return NetworkUsageSnapshot(
                rxBytesPerSecond: 0,
                txBytesPerSecond: 0,
                status: .stable,
                totalRxBytes: cumulativeRxBytes,
                totalTxBytes: cumulativeTxBytes
            )
        }
        
        var totalRxDelta: UInt64 = 0
        var totalTxDelta: UInt64 = 0
        
        for (name, current) in currentCounters {
            if let prev = baselines[name] {
                // If counters decreased (interface reset, reboot, or wrap), reset baseline for this interface
                if current.rxBytes >= prev.rxBytes && current.txBytes >= prev.txBytes {
                    totalRxDelta += (current.rxBytes - prev.rxBytes)
                    totalTxDelta += (current.txBytes - prev.txBytes)
                }
            }
        }
        
        cumulativeRxBytes &+= totalRxDelta
        cumulativeTxBytes &+= totalTxDelta
        
        baselines = currentCounters
        previousTimestamp = now
        
        let rxRate = Double(totalRxDelta) / elapsed
        let txRate = Double(totalTxDelta) / elapsed
        
        return NetworkUsageSnapshot(
            rxBytesPerSecond: rxRate,
            txBytesPerSecond: txRate,
            status: .stable,
            totalRxBytes: cumulativeRxBytes,
            totalTxBytes: cumulativeTxBytes
        )
    }
    
    /// Reads 64-bit byte counters from eligible physical network interfaces.
    private func readInterfaceCounters() -> [String: InterfaceBaseline] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0
        
        if sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) < 0 {
            return [:]
        }
        
        var buffer = [UInt8](repeating: 0, count: len)
        if sysctl(&mib, UInt32(mib.count), &buffer, &len, nil, 0) < 0 {
            return [:]
        }
        
        var results: [String: InterfaceBaseline] = [:]
        var offset = 0
        
        while offset < len {
            let msgPtr = buffer.withUnsafeBytes { rawBuffer -> UnsafePointer<if_msghdr>? in
                guard offset + MemoryLayout<if_msghdr>.size <= len else { return nil }
                return rawBuffer.baseAddress?.advanced(by: offset).assumingMemoryBound(to: if_msghdr.self)
            }
            
            guard let msg = msgPtr else { break }
            let msgLen = Int(msg.pointee.ifm_msglen)
            guard msgLen > 0, offset + msgLen <= len else { break }
            
            if msg.pointee.ifm_type == RTM_IFINFO2 {
                buffer.withUnsafeBytes { rawBuffer in
                    let if2Ptr = rawBuffer.baseAddress?.advanced(by: offset).assumingMemoryBound(to: if_msghdr2.self)
                    if let if2 = if2Ptr {
                        let data = if2.pointee.ifm_data
                        
                        // Extract interface name from sockaddr_dl that immediately follows if_msghdr2
                        let sdlOffset = offset + MemoryLayout<if_msghdr2>.size
                        if sdlOffset + MemoryLayout<sockaddr_dl>.size <= offset + msgLen {
                            let sdlPtr = rawBuffer.baseAddress?.advanced(by: sdlOffset).assumingMemoryBound(to: sockaddr_dl.self)
                            if let sdl = sdlPtr {
                                let nlen = Int(sdl.pointee.sdl_nlen)
                                if nlen > 0 {
                                    let nameBytes = withUnsafeBytes(of: sdl.pointee.sdl_data) { rawData in
                                        Array(rawData.prefix(nlen))
                                    }
                                    let name = String(decoding: nameBytes, as: UTF8.self)
                                    
                                    // Filter for physical interfaces (e.g. en0, en1), excluding loopback (lo0) and tunnels (utun, awdl, p2p, bridge)
                                    if isEligiblePhysicalInterface(name) {
                                        results[name] = InterfaceBaseline(
                                            rxBytes: data.ifi_ibytes,
                                            txBytes: data.ifi_obytes
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            offset += msgLen
        }
        
        return results
    }
    
    private func isEligiblePhysicalInterface(_ name: String) -> Bool {
        // Exclude loopback, VPN tunnels, Apple Wireless Direct Link, bridge
        if name.hasPrefix("lo") || name.hasPrefix("utun") || name.hasPrefix("awdl") || name.hasPrefix("p2p") || name.hasPrefix("bridge") || name.hasPrefix("llw") {
            return false
        }
        // Match ethernet/Wi-Fi devices (typically en0, en1, en2, etc.)
        return name.hasPrefix("en")
    }
}
