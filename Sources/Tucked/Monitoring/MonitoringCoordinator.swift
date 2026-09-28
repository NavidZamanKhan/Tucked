import Foundation
import AppKit

/// Central coordinator managing passive (closed) and diagnostic (open) sampling lifecycles.
public final class MonitoringCoordinator: @unchecked Sendable {
    public enum Mode: Sendable {
        case passive
        case diagnostic
    }
    
    // Core samplers
    private let cpuSampler = CPUSampler()
    private let memorySampler = MemorySampler()
    private let memoryPressureMonitor = MemoryPressureMonitor()
    private let networkSampler = NetworkSampler()
    public let historyStore = HistoryStore(capacity: 90)
    
    // Diagnostic services (active only while shelf is open)
    private let processSampler = ProcessSampler()
    private let thermalProvider = ThermalProvider()
    private let wifiReader = WiFiReader()
    private let networkDiagnostics = NetworkDiagnosticsService()
    
    // Retained diagnostic state across polling intervals
    private var lastThermalSnapshot = ThermalSnapshot()
    private var lastDiagnosticsSnapshot = NetworkDiagnosticsSnapshot(isMeasuring: true)
    private var lastTopCPU: [ProcessItem] = []
    private var lastTopMemory: [ProcessItem] = []
    
    // Dispatch and scheduling
    private let coordinatorQueue = DispatchQueue(label: "ai.mpiv.Tucked.Coordinator", qos: .utility)
    private var passiveTimer: DispatchSourceTimer?
    private var diagnosticTimer: DispatchSourceTimer?
    
    // Generational ticket for cancellation and stale publication prevention
    private var diagnosticGeneration: UInt64 = 0
    private var currentMode: Mode = .passive
    private let lock = NSLock()
    
    public var mode: Mode {
        lock.lock()
        defer { lock.unlock() }
        return currentMode
    }
    
    // Handlers publishing to UI
    public var onSystemSnapshot: (@Sendable (SystemSnapshot) -> Void)?
    public var onDiagnosticSnapshot: (@Sendable (DiagnosticSnapshot) -> Void)?
    
    public init() {
        memoryPressureMonitor.start()
    }
    
    deinit {
        stop()
    }
    
    public func start() {
        startPassiveHeartbeat()
    }
    
    public func stop() {
        lock.lock()
        currentMode = .passive
        diagnosticGeneration &+= 1
        lock.unlock()
        
        stopDiagnosticHeartbeat()
        stopPassiveHeartbeat()
        memoryPressureMonitor.stop()
        thermalProvider.stop()
        networkDiagnostics.reset()
    }
    
    public func resetNetworkTotals() {
        networkSampler.resetTotals()
        coordinatorQueue.async { [weak self] in
            self?.tickPassive()
        }
    }
    
    // MARK: - Mode Transitions
    
    public func shelfDidOpen() {
        lock.lock()
        currentMode = .diagnostic
        diagnosticGeneration &+= 1
        let gen = diagnosticGeneration
        lock.unlock()
        
        TuckedLog.sampling.info("Entering Diagnostic Mode (gen: \(gen))")
        
        // Initial process pair: T0 now, T1 in ~300ms
        coordinatorQueue.async { [weak self] in
            guard let self = self else { return }
            _ = self.processSampler.sample()
            
            // Immediate fast thermal, Wi-Fi, and IP reads
            let initialThermal = self.thermalProvider.sample()
            self.lastThermalSnapshot = initialThermal
            let wifiResult = self.wifiReader.read()
            let localIP = NetworkDiagnosticsService.resolveLocalIP()
            
            self.lastDiagnosticsSnapshot = NetworkDiagnosticsSnapshot(
                latencyMs: self.lastDiagnosticsSnapshot.latencyMs,
                jitterMs: self.lastDiagnosticsSnapshot.jitterMs,
                wifiRSSI: wifiResult.rssi,
                wifiLinkRateMbps: wifiResult.linkRateMbps,
                interfaceName: wifiResult.interfaceName,
                localIP: localIP,
                publicIP: self.lastDiagnosticsSnapshot.publicIP,
                isInternetUp: self.lastDiagnosticsSnapshot.isInternetUp,
                isMeasuring: true
            )
            
            // Initial publication
            self.publishDiagnosticSnapshot(
                thermal: initialThermal,
                topCPU: self.lastTopCPU,
                topMemory: self.lastTopMemory,
                diagnostics: self.lastDiagnosticsSnapshot,
                isMeasuringCPU: self.lastTopCPU.isEmpty
            )
            
            // Immediate network diagnostics probe
            self.networkDiagnostics.probe { [weak self] latency, jitter, health, isUp in
                guard let self = self else { return }
                self.lock.lock()
                guard self.currentMode == .diagnostic && self.diagnosticGeneration == gen else {
                    self.lock.unlock()
                    return
                }
                self.lock.unlock()
                
                let diag = NetworkDiagnosticsSnapshot(
                    latencyMs: latency ?? self.lastDiagnosticsSnapshot.latencyMs,
                    jitterMs: jitter ?? self.lastDiagnosticsSnapshot.jitterMs,
                    wifiRSSI: wifiResult.rssi ?? self.lastDiagnosticsSnapshot.wifiRSSI,
                    wifiLinkRateMbps: wifiResult.linkRateMbps ?? self.lastDiagnosticsSnapshot.wifiLinkRateMbps,
                    interfaceName: wifiResult.interfaceName ?? self.lastDiagnosticsSnapshot.interfaceName,
                    localIP: localIP ?? self.lastDiagnosticsSnapshot.localIP,
                    publicIP: self.lastDiagnosticsSnapshot.publicIP,
                    isInternetUp: isUp,
                    isMeasuring: false
                )
                self.lastDiagnosticsSnapshot = diag
                
                self.publishDiagnosticSnapshot(
                    thermal: self.lastThermalSnapshot,
                    topCPU: self.lastTopCPU,
                    topMemory: self.lastTopMemory,
                    diagnostics: diag,
                    isMeasuringCPU: self.lastTopCPU.isEmpty
                )
            }
            
            // Asynchronously fetch public IP (shelf diagnostic mode only)
            self.networkDiagnostics.fetchPublicIP { [weak self] publicIP in
                guard let self = self, let publicIP = publicIP else { return }
                self.lock.lock()
                guard self.currentMode == .diagnostic && self.diagnosticGeneration == gen else {
                    self.lock.unlock()
                    return
                }
                self.lock.unlock()
                
                self.coordinatorQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.lock.lock()
                    guard self.currentMode == .diagnostic && self.diagnosticGeneration == gen else {
                        self.lock.unlock()
                        return
                    }
                    self.lock.unlock()
                    
                    let diag = NetworkDiagnosticsSnapshot(
                        latencyMs: self.lastDiagnosticsSnapshot.latencyMs,
                        jitterMs: self.lastDiagnosticsSnapshot.jitterMs,
                        wifiRSSI: self.lastDiagnosticsSnapshot.wifiRSSI,
                        wifiLinkRateMbps: self.lastDiagnosticsSnapshot.wifiLinkRateMbps,
                        interfaceName: self.lastDiagnosticsSnapshot.interfaceName,
                        localIP: self.lastDiagnosticsSnapshot.localIP,
                        publicIP: publicIP,
                        isInternetUp: self.lastDiagnosticsSnapshot.isInternetUp,
                        isMeasuring: self.lastDiagnosticsSnapshot.isMeasuring
                    )
                    self.lastDiagnosticsSnapshot = diag
                    
                    self.publishDiagnosticSnapshot(
                        thermal: self.lastThermalSnapshot,
                        topCPU: self.lastTopCPU,
                        topMemory: self.lastTopMemory,
                        diagnostics: diag,
                        isMeasuringCPU: self.lastTopCPU.isEmpty
                    )
                }
            }
            
            // T1 process sample after ~300ms
            self.coordinatorQueue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                guard self.currentMode == .diagnostic && self.diagnosticGeneration == gen else {
                    self.lock.unlock()
                    return
                }
                self.lock.unlock()
                
                let processResult = self.processSampler.sample()
                self.lastTopCPU = processResult.topCPU
                self.lastTopMemory = processResult.topMemory
                
                self.publishDiagnosticSnapshot(
                    thermal: self.lastThermalSnapshot,
                    topCPU: processResult.topCPU,
                    topMemory: processResult.topMemory,
                    diagnostics: self.lastDiagnosticsSnapshot,
                    isMeasuringCPU: false
                )
            }
        }
        
        startDiagnosticHeartbeat(generation: gen)
    }
    
    public func shelfDidClose() {
        lock.lock()
        currentMode = .passive
        diagnosticGeneration &+= 1
        let gen = diagnosticGeneration
        lock.unlock()
        
        TuckedLog.sampling.info("Exiting Diagnostic Mode (gen: \(gen))")
        
        stopDiagnosticHeartbeat()
        processSampler.reset()
        thermalProvider.stop()
        networkDiagnostics.reset()
        lastDiagnosticsSnapshot = NetworkDiagnosticsSnapshot(isMeasuring: true)
        lastTopCPU.removeAll()
        lastTopMemory.removeAll()
    }
    
    // MARK: - Sleep & Wake
    
    public func handleSystemSleep() {
        TuckedLog.sampling.info("System will sleep - stopping sampling and diagnostics")
        shelfDidClose()
        stopPassiveHeartbeat()
        cpuSampler.resetBaseline()
        networkSampler.resetBaseline()
    }
    
    public func handleSystemWake() {
        TuckedLog.sampling.info("System did wake - preserving history, marking discontinuity, and refreshing baselines")
        // Preserve in-memory history across sleep and insert one discontinuity gap before post-wake samples
        historyStore.markDiscontinuity()
        
        // Re-establish baselines immediately to eliminate bogus wake spikes
        cpuSampler.resetBaseline()
        _ = cpuSampler.sample()
        networkSampler.resetBaseline()
        _ = networkSampler.sample()
        memoryPressureMonitor.reconcile()
        
        // Resume passive sampling with a 1-second interval so the first tick measures true post-wake delta
        startPassiveHeartbeat(delay: 1.0)
    }
    
    // MARK: - Passive Loop (~1 Hz)
    
    private func startPassiveHeartbeat(delay: TimeInterval = 0.0) {
        stopPassiveHeartbeat()
        
        let timer = DispatchSource.makeTimerSource(queue: coordinatorQueue)
        let deadline: DispatchTime = delay > 0 ? (.now() + delay) : .now()
        timer.schedule(deadline: deadline, repeating: .seconds(1), leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.tickPassive()
        }
        timer.resume()
        self.passiveTimer = timer
    }
    
    private func stopPassiveHeartbeat() {
        passiveTimer?.cancel()
        passiveTimer = nil
    }
    
    private func tickPassive() {
        let cpu = cpuSampler.sample()
        let pressure = memoryPressureMonitor.status
        let memory = memorySampler.sample(pressureStatus: pressure)
        let network = networkSampler.sample()
        
        historyStore.append(
            cpu: cpu.totalUsage,
            memory: memory.usedPercentage,
            rx: network.rxBytesPerSecond,
            tx: network.txBytesPerSecond
        )
        
        let snapshot = SystemSnapshot(cpu: cpu, memory: memory, network: network)
        
        DispatchQueue.main.async { [weak self] in
            self?.onSystemSnapshot?(snapshot)
        }
    }
    
    // MARK: - Diagnostic Loop (Open Shelf Only)
    
    private func startDiagnosticHeartbeat(generation: UInt64) {
        stopDiagnosticHeartbeat()
        
        var tickCount: UInt64 = 0
        let timer = DispatchSource.makeTimerSource(queue: coordinatorQueue)
        timer.schedule(deadline: .now() + 1.0, repeating: .seconds(1), leeway: .milliseconds(100))
        
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            guard self.currentMode == .diagnostic && self.diagnosticGeneration == generation else {
                self.lock.unlock()
                return
            }
            self.lock.unlock()
            
            tickCount &+= 1
            
            // Process scan every 1 second
            let processResult = self.processSampler.sample()
            self.lastTopCPU = processResult.topCPU
            self.lastTopMemory = processResult.topMemory
            
            if tickCount % 2 == 0 {
                let currentThermal = self.thermalProvider.sample()
                self.lastThermalSnapshot = currentThermal
                let wifiResult = self.wifiReader.read()
                
                self.networkDiagnostics.probe { [weak self] latency, jitter, health, isUp in
                    guard let self = self else { return }
                    self.lock.lock()
                    guard self.currentMode == .diagnostic && self.diagnosticGeneration == generation else {
                        self.lock.unlock()
                        return
                    }
                    self.lock.unlock()
                    
                    let currentLocalIP = NetworkDiagnosticsService.resolveLocalIP()
                    let diag = NetworkDiagnosticsSnapshot(
                        latencyMs: latency ?? self.lastDiagnosticsSnapshot.latencyMs,
                        jitterMs: jitter ?? self.lastDiagnosticsSnapshot.jitterMs,
                        wifiRSSI: wifiResult.rssi ?? self.lastDiagnosticsSnapshot.wifiRSSI,
                        wifiLinkRateMbps: wifiResult.linkRateMbps ?? self.lastDiagnosticsSnapshot.wifiLinkRateMbps,
                        interfaceName: wifiResult.interfaceName ?? self.lastDiagnosticsSnapshot.interfaceName,
                        localIP: currentLocalIP ?? self.lastDiagnosticsSnapshot.localIP,
                        publicIP: self.lastDiagnosticsSnapshot.publicIP,
                        isInternetUp: isUp,
                        isMeasuring: false
                    )
                    self.lastDiagnosticsSnapshot = diag
                    
                    self.publishDiagnosticSnapshot(
                        thermal: self.lastThermalSnapshot,
                        topCPU: self.lastTopCPU,
                        topMemory: self.lastTopMemory,
                        diagnostics: diag,
                        isMeasuringCPU: false
                    )
                }
            } else {
                self.publishDiagnosticSnapshot(
                    thermal: self.lastThermalSnapshot,
                    topCPU: self.lastTopCPU,
                    topMemory: self.lastTopMemory,
                    diagnostics: self.lastDiagnosticsSnapshot,
                    isMeasuringCPU: false
                )
            }
        }
        
        timer.resume()
        self.diagnosticTimer = timer
    }
    
    private func stopDiagnosticHeartbeat() {
        diagnosticTimer?.cancel()
        diagnosticTimer = nil
    }
    
    private func publishDiagnosticSnapshot(
        thermal: ThermalSnapshot,
        topCPU: [ProcessItem],
        topMemory: [ProcessItem],
        diagnostics: NetworkDiagnosticsSnapshot,
        isMeasuringCPU: Bool
    ) {
        let snapshot = DiagnosticSnapshot(
            thermal: thermal,
            topCPUProcesses: topCPU,
            topMemoryProcesses: topMemory,
            networkDiagnostics: diagnostics,
            isMeasuringCPUProcesses: isMeasuringCPU
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.onDiagnosticSnapshot?(snapshot)
        }
    }
}
