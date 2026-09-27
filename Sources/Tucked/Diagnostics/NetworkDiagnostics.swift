import Foundation
import Network
import Darwin

/// Diagnostics service measuring connection latency and jitter via TCP setup to public resolver,
/// as well as local IP, public IP, and active internet connectivity.
public final class NetworkDiagnosticsService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ai.mpiv.Tucked.NetworkDiagnostics", qos: .utility)
    private var activeConnection: NWConnection?
    private var latencyHistory: [Double] = []
    private let maxHistory = 10
    private let lock = NSLock()
    private var isCancelled: Bool = false
    private var isCompleted: Bool = false
    
    // Cached public IP state (shelf diagnostic mode only)
    private var cachedPublicIP: String?
    private var publicIPTask: URLSessionDataTask?
    private var lastPublicIPFetchTime: Date?
    
    public init() {}
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = true
        activeConnection?.cancel()
        activeConnection = nil
        publicIPTask?.cancel()
        publicIPTask = nil
        latencyHistory.removeAll()
    }
    
    // MARK: - Local IP Resolution (Native Darwin getifaddrs)
    
    public static func resolveLocalIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var primaryIP: String?
        var fallbackIP: String?
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING),
                  (flags & IFF_LOOPBACK) == 0 else {
                continue
            }
            
            guard let sa = ptr.pointee.ifa_addr else { continue }
            if sa.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = hostname.withUnsafeBufferPointer { ptr in
                        ptr.baseAddress.map { String(cString: $0) }
                    } ?? ""
                    let name = String(cString: ptr.pointee.ifa_name)
                    if !ip.hasPrefix("169.254.") {
                        if name == "en0" {
                            primaryIP = ip
                            break
                        } else if primaryIP == nil && name.hasPrefix("en") {
                            primaryIP = ip
                        } else if fallbackIP == nil {
                            fallbackIP = ip
                        }
                    }
                }
            }
        }
        return primaryIP ?? fallbackIP
    }
    
    // MARK: - Public IP Resolution (Diagnostic Mode Only)
    
    public func fetchPublicIP(completion: @escaping @Sendable (String?) -> Void) {
        lock.lock()
        if let cached = cachedPublicIP, let lastTime = lastPublicIPFetchTime, Date().timeIntervalSince(lastTime) < 300 {
            let ip = cached
            lock.unlock()
            completion(ip)
            return
        }
        publicIPTask?.cancel()
        
        guard let url = URL(string: "https://api.ipify.org") else {
            lock.unlock()
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3.0
        config.timeoutIntervalForResource = 3.0
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            
            if let data = data, let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !ip.isEmpty {
                self.cachedPublicIP = ip
                self.lastPublicIPFetchTime = Date()
                completion(ip)
            } else {
                completion(self.cachedPublicIP)
            }
        }
        self.publicIPTask = task
        lock.unlock()
        task.resume()
    }
    
    // MARK: - Latency & Reachability Probe
    
    public func probe(completion: @escaping @Sendable (Double?, Double?, NetworkHealthStatus, Bool) -> Void) {
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
            
            completion(nil, nil, .poor, false)
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
                completion(elapsedMs, jitter, health, true)
                
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
                completion(nil, nil, .poor, false)
                
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
