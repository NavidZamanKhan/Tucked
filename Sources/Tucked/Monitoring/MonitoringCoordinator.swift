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
    
    // Dispatch and scheduling
    private let coordinatorQueue = DispatchQueue(label: "ai.mpiv.Tucked.Coordinator", qos: .utility)
    private var passiveTimer: DispatchSourceTimer?
    private var diagnosticTimer: DispatchSourceTimer?
    
    // Generational ticket for cancellation and stale publication prevention
    private var diagnosticGeneration: UInt64 = 0
    private var currentMode: Mode = .passive
    private let lock = NSLock()
    
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
            
            // Initial placeholder publication
            self.publishDiagnosticSnapshot(
                thermal: ThermalSnapshot(),
                topCPU: [],
                topMemory: [],
                diagnostics: NetworkDiagnosticsSnapshot(isMeasuring: true),
                isMeasuringCPU: true
            )
            
            // Initial fast thermal read
            let initialThermal = self.thermalProvider.sample()
            self.publishDiagnosticSnapshot(
                thermal: initialThermal,
                topCPU: [],
                topMemory: [],
                diagnostics: NetworkDiagnosticsSnapshot(isMeasuring: true),
                isMeasuringCPU: true
            )
            
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
                self.publishDiagnosticSnapshot(
                    thermal: initialThermal,
                    topCPU: processResult.topCPU,
                    topMemory: processResult.topMemory,
                    diagnostics: NetworkDiagnosticsSnapshot(isMeasuring: true),
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
    }
    
    // MARK: - Sleep & Wake
    
    public func handleSystemSleep() {
        TuckedLog.sampling.info("System will sleep - resetting baselines and stopping diagnostics")
        shelfDidClose()
        cpuSampler.resetBaseline()
        networkSampler.resetBaseline()
    }
    
    public func handleSystemWake() {
        TuckedLog.sampling.info("System did wake - refreshing baselines")
        cpuSampler.resetBaseline()
        networkSampler.resetBaseline()
        memoryPressureMonitor.reconcile()
        historyStore.clear()
    }
    
    // MARK: - Passive Loop (~1 Hz)
    
    private func startPassiveHeartbeat() {
        stopPassiveHeartbeat()
        
        let timer = DispatchSource.makeTimerSource(queue: coordinatorQueue)
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(100))
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
            
            if tickCount % 2 == 0 {
                let currentThermal = self.thermalProvider.sample()
                let wifiResult = self.wifiReader.read()
                let topCPU = processResult.topCPU
                let topMemory = processResult.topMemory
                
                self.networkDiagnostics.probe { [weak self] latency, jitter, health in
                    guard let self = self else { return }
                    self.lock.lock()
                    guard self.currentMode == .diagnostic && self.diagnosticGeneration == generation else {
                        self.lock.unlock()
                        return
                    }
                    self.lock.unlock()
                    
                    let diag = NetworkDiagnosticsSnapshot(
                        latencyMs: latency,
                        jitterMs: jitter,
                        wifiRSSI: wifiResult.rssi,
                        wifiLinkRateMbps: wifiResult.linkRateMbps,
                        interfaceName: wifiResult.interfaceName,
                        isMeasuring: false
                    )
                    
                    self.publishDiagnosticSnapshot(
                        thermal: currentThermal,
                        topCPU: topCPU,
                        topMemory: topMemory,
                        diagnostics: diag,
                        isMeasuringCPU: false
                    )
                }
            } else {
                self.publishDiagnosticSnapshot(
                    thermal: ThermalSnapshot(),
                    topCPU: processResult.topCPU,
                    topMemory: processResult.topMemory,
                    diagnostics: NetworkDiagnosticsSnapshot(isMeasuring: false),
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
