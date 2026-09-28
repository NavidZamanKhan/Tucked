import Testing
import Foundation
import AppKit
@testable import Tucked

@Suite("HistoryStore Tests")
struct HistoryStoreTests {
    @Test func testRingBufferCapacityAndOrdering() {
        let store = HistoryStore(capacity: 5)
        #expect(store.samples().isEmpty)
        
        for i in 1...5 {
            store.append(cpu: Double(i), memory: Double(i * 10), rx: Double(i * 100), tx: Double(i * 50))
        }
        
        var samples = store.samples()
        #expect(samples.count == 5)
        #expect(samples.first?.cpu == 1.0)
        #expect(samples.last?.cpu == 5.0)
        
        // Push 6th item, should evict 1st item
        store.append(cpu: 6.0, memory: 60.0, rx: 600.0, tx: 300.0)
        samples = store.samples()
        #expect(samples.count == 5)
        #expect(samples.first?.cpu == 2.0)
        #expect(samples.last?.cpu == 6.0)
        
        store.clear()
        #expect(store.samples().isEmpty)
    }
}

@Suite("Formatters Tests")
struct FormattersTests {
    @Test func testMenuBarRateFormatting() {
        #expect(TuckedFormatter.formatMenuBarRate(0) == "0K")
        #expect(TuckedFormatter.formatMenuBarRate(912) == "912B")
        #expect(TuckedFormatter.formatMenuBarRate(7_000) == "7K")
        #expect(TuckedFormatter.formatMenuBarRate(840_000) == "840K")
        #expect(TuckedFormatter.formatMenuBarRate(1_200_000) == "1.2M")
        #expect(TuckedFormatter.formatMenuBarRate(24_000_000) == "24M")
        #expect(TuckedFormatter.formatMenuBarRate(1_100_000_000) == "1.1G")
    }
    
    @Test func testPanelRateFormatting() {
        #expect(TuckedFormatter.formatPanelRate(0) == "0 KB/s")
        #expect(TuckedFormatter.formatPanelRate(7_000) == "7 KB/s")
        #expect(TuckedFormatter.formatPanelRate(1_200_000) == "1.2 MB/s")
    }
    
    @Test func testByteFormatting() {
        // Binary (1024-based) memory formatting matching macOS Activity Monitor
        #expect(TuckedFormatter.formatBytes(512 * 1024 * 1024) == "512 MB")
        #expect(TuckedFormatter.formatBytes(16 * 1024 * 1024 * 1024) == "16.0 GB")
    }
    
    @Test func testPercentageFormatting() {
        #expect(TuckedFormatter.formatPercent(35.2) == "35%")
        #expect(TuckedFormatter.formatPercent(99.8) == "100%")
        #expect(TuckedFormatter.formatPercent(-5.0) == "0%")
    }
    
    @Test func testTemperatureFormatting() {
        #expect(TuckedFormatter.formatTemperature(54) == "54°C")
        #expect(TuckedFormatter.formatTemperature(nil) == "-")
    }
    
    @Test func testFanFormatting() {
        #expect(TuckedFormatter.formatFanRPM(isFanless: true, rpms: []) == "Fanless")
        #expect(TuckedFormatter.formatFanRPM(isFanless: false, rpms: []) == "-")
        #expect(TuckedFormatter.formatFanRPM(isFanless: false, rpms: [0]) == "0 RPM (Idle)")
        #expect(TuckedFormatter.formatFanRPM(isFanless: false, rpms: [0, 0]) == "0 / 0 RPM (Idle)")
        #expect(TuckedFormatter.formatFanRPM(isFanless: false, rpms: [1840]) == "1840 RPM")
        #expect(TuckedFormatter.formatFanRPM(isFanless: false, rpms: [1840, 1920]) == "1840 / 1920 RPM")
    }
}

@Suite("ProcessTerminationPolicy Tests")
struct ProcessTerminationPolicyTests {
    @Test func testSystemProcessesAreProtected() {
        let currentUID = getuid()
        
        // PID 0 and 1 never closable
        #expect(!ProcessTerminationPolicy.isClosable(pid: 0, name: "kernel_task", ownerUID: 0))
        #expect(!ProcessTerminationPolicy.isClosable(pid: 1, name: "launchd", ownerUID: 0))
        
        // System and session critical processes protected
        #expect(!ProcessTerminationPolicy.isClosable(pid: 100, name: "WindowServer", ownerUID: currentUID))
        #expect(!ProcessTerminationPolicy.isClosable(pid: 101, name: "loginwindow", ownerUID: currentUID))
        #expect(!ProcessTerminationPolicy.isClosable(pid: 102, name: "Finder", ownerUID: currentUID))
        #expect(!ProcessTerminationPolicy.isClosable(pid: 103, name: "Dock", ownerUID: currentUID))
        #expect(!ProcessTerminationPolicy.isClosable(pid: 104, name: "SystemUIServer", ownerUID: currentUID))
        
        // Own process is protected
        let ownPID = ProcessInfo.processInfo.processIdentifier
        #expect(!ProcessTerminationPolicy.isClosable(pid: ownPID, name: "Tucked", ownerUID: currentUID))
        
        // Other user's process protected
        #expect(!ProcessTerminationPolicy.isClosable(pid: 200, name: "node", ownerUID: currentUID + 1))
        
        // Same user CLI process is closable
        #expect(ProcessTerminationPolicy.isClosable(pid: 300, name: "node", ownerUID: currentUID))
    }
    
    @Test func testTerminateRefusesProtectedProcesses() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        #expect(!ProcessTerminationPolicy.terminate(pid: 0, expectedName: "kernel_task"))
        #expect(!ProcessTerminationPolicy.terminate(pid: 1, expectedName: "launchd"))
        #expect(!ProcessTerminationPolicy.terminate(pid: ownPID, expectedName: "Tucked"))
    }
}

@Suite("Calculation and Math Fixtures")
struct CalculationFixturesTests {
    @Test func testDarwinCPUTicksIndexMapping() {
        // Darwin Mach constants from mach/machine.h
        // CPU_STATE_USER = 0, CPU_STATE_SYSTEM = 1, CPU_STATE_IDLE = 2, CPU_STATE_NICE = 3
        #expect(CPU_STATE_USER == 0)
        #expect(CPU_STATE_SYSTEM == 1)
        #expect(CPU_STATE_IDLE == 2)
        #expect(CPU_STATE_NICE == 3)
    }
    
    @Test func testCPUDeltasFixture() {
        // From dossier: U=10, N=5, S=15, I=70 yields User 15%, System 15%, Total 30%
        let u: UInt64 = 10
        let n: UInt64 = 5
        let s: UInt64 = 15
        let i: UInt64 = 70
        let total = u + n + s + i
        #expect(total == 100)
        
        let userPercent = Double(u + n) / Double(total) * 100.0
        let systemPercent = Double(s) / Double(total) * 100.0
        let totalPercent = Double(u + n + s) / Double(total) * 100.0
        
        #expect(userPercent == 15.0)
        #expect(systemPercent == 15.0)
        #expect(totalPercent == 30.0)
    }
    
    @Test func testMemoryAccountingFormulaFixture() {
        // From dossier: active=100, inactive=80, speculative=20, wired=40, compressor=10, purgeable=5, external=65
        // Used pages = active + inactive + speculative + wired + compressor - purgeable - external
        // = 100 + 80 + 20 + 40 + 10 - 5 - 65 = 180 pages.
        // At 16 KiB per page, 180 * 16384 = 2,949,120 bytes.
        let active: Int64 = 100
        let inactive: Int64 = 80
        let speculative: Int64 = 20
        let wired: Int64 = 40
        let compressor: Int64 = 10
        let purgeable: Int64 = 5
        let external: Int64 = 65
        let pageSize: UInt64 = 16384
        
        let usedPages = active + inactive + speculative + wired + compressor - purgeable - external
        #expect(usedPages == 180)
        
        let usedBytes = UInt64(usedPages) * pageSize
        #expect(usedBytes == 2_949_120)
    }
    
    @Test func testJitterCalculationFixture() {
        // From dossier: latencies 10, 14, 12 ms yield successive differences |14-10|=4, |12-14|=2.
        // Mean absolute successive difference = (4 + 2) / 2 = 3 ms.
        let latencies = [10.0, 14.0, 12.0]
        var sumDiff: Double = 0
        for i in 1..<latencies.count {
            sumDiff += abs(latencies[i] - latencies[i - 1])
        }
        let jitter = sumDiff / Double(latencies.count - 1)
        #expect(jitter == 3.0)
    }
    
    @Test func testFreeMemoryCalculationFixture() {
        let snapshot = MemoryUsageSnapshot(
            usedBytes: 12_000_000_000,
            totalPhysicalBytes: 16_000_000_000,
            swapBytes: 0,
            compressedBytes: 0,
            usedPercentage: 75.0,
            status: .normal
        )
        #expect(snapshot.freeBytes == 4_000_000_000)
    }
    
    @Test func testFreeMemoryUnderflowFixture() {
        let snapshot = MemoryUsageSnapshot(
            usedBytes: 20_000_000_000,
            totalPhysicalBytes: 16_000_000_000,
            swapBytes: 0,
            compressedBytes: 0,
            usedPercentage: 100.0,
            status: .critical
        )
        #expect(snapshot.freeBytes == 0)
    }
    
    @Test func testMemorySnapshotBreakdownFixture() {
        let snapshot = MemoryUsageSnapshot(
            usedBytes: 12_000_000_000,
            totalPhysicalBytes: 16_000_000_000,
            swapBytes: 1_000_000_000,
            compressedBytes: 2_000_000_000,
            appBytes: 6_000_000_000,
            wiredBytes: 4_000_000_000,
            usedPercentage: 75.0,
            status: .normal
        )
        #expect(snapshot.appBytes == 6_000_000_000)
        #expect(snapshot.wiredBytes == 4_000_000_000)
        #expect(snapshot.compressedBytes == 2_000_000_000)
        #expect(snapshot.freeBytes == 4_000_000_000)
        #expect(snapshot.swapBytes == 1_000_000_000)
    }
}

@Suite("ThermalProvider Tests")
struct ThermalProviderTests {
    @Test func testThermalProviderSample() {
        let provider = ThermalProvider()
        defer { provider.stop() }
        let snapshot = provider.sample()
        
        #expect(snapshot.state != .unavailable)
        if let temp = snapshot.cpuTemperatureCelsius {
            #expect(temp > 0 && temp < 130)
        }
    }
}

@Suite("ProcessIconProvider Tests")
struct ProcessIconProviderTests {
    @Test @MainActor func testProcessIconResolutionAndCaching() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let provider = ProcessIconProvider.shared
        provider.clear()
        
        // Resolves an icon for a running process
        let icon1 = provider.icon(for: ownPID)
        #expect(icon1.size.width > 0 && icon1.size.height > 0)
        
        // Cache hit returns same object reference
        let icon2 = provider.icon(for: ownPID)
        #expect(icon1 === icon2)
        
        // Resolves default fallback icon for PID 1 (launchd)
        let fallbackIcon = provider.icon(for: 1)
        #expect(fallbackIcon.size.width > 0)
    }
}

@Suite("AppTheme Tests")
struct AppThemeTests {
    @Test func testAppThemeOptionsAndTitles() {
        #expect(AppTheme.allCases.count == 3)
        #expect(AppTheme.system.title == "System")
        #expect(AppTheme.light.title == "Light")
        #expect(AppTheme.dark.title == "Dark")
    }
    
    @Test func testPreferencesThemePersistence() {
        let suite = UserDefaults(suiteName: "test.preferences.theme.\(UUID().uuidString)")!
        let prefs = Preferences(defaults: suite)
        #expect(prefs.appTheme == .system)
        
        prefs.appTheme = .dark
        #expect(prefs.appTheme == .dark)
        
        prefs.appTheme = .light
        #expect(prefs.appTheme == .light)
    }
}

@Suite("ProcessSampler Tests")
struct ProcessSamplerTests {
    @Test func testProcessSamplerDeferredResolution() {
        let sampler = ProcessSampler()
        sampler.reset()
        
        // First sample (initial baseline)
        let first = sampler.sample()
        #expect(first.isMeasuringCPU)
        #expect(first.topMemory.count <= 6)
        
        // Memory should be sorted descending
        if first.topMemory.count > 1 {
            for i in 0..<(first.topMemory.count - 1) {
                #expect(first.topMemory[i].memoryBytes >= first.topMemory[i + 1].memoryBytes)
            }
        }
        
        // Every finalist must have a valid non-empty name and positive PID
        for item in first.topMemory {
            #expect(!item.name.isEmpty)
            #expect(item.pid > 0)
        }
        
        // Second sample (with CPU deltas computed)
        let second = sampler.sample()
        #expect(!second.isMeasuringCPU)
        
        // CPU should be sorted descending
        if second.topCPU.count > 1 {
            for i in 0..<(second.topCPU.count - 1) {
                #expect(second.topCPU[i].cpuUsagePercent >= second.topCPU[i + 1].cpuUsagePercent)
            }
        }
        
        for item in second.topCPU {
            #expect(!item.name.isEmpty)
            #expect(item.pid > 0)
        }
    }
}

@Suite("Sparkline Views Tests")
@MainActor
struct SparklineViewsTests {
    @Test func testSparklineViewInit() {
        let view = SparklineView(data: [10, 25, 50, 75, 100], maxScale: 100, color: .blue, capacity: 90)
        #expect(view.data.count == 5)
        #expect(view.maxScale == 100)
        #expect(view.capacity == 90)
    }
    
    @Test func testBidirectionalNetworkSparklineViewInit() {
        let view = BidirectionalNetworkSparklineView(
            uploadData: [0, 500, 10000, 0],
            downloadData: [0, 1500, 20000, 0],
            uploadColor: .teal,
            downloadColor: .pink,
            capacity: 90
        )
        #expect(view.uploadData.count == 4)
        #expect(view.downloadData.count == 4)
        #expect(view.capacity == 90)
    }
}

@Suite("MachineInfo Tests")
struct MachineInfoTests {
    @Test func testMachineInfoCurrent() {
        let info = MachineInfo.current
        #expect(!info.model.isEmpty)
        #expect(!info.chip.isEmpty)
        #expect(info.coreCount > 0)
        #expect(info.memoryBytes > 0)
        #expect(!info.osVersion.isEmpty)
        #expect(info.architecture == "arm64")
        #expect(!info.formattedMemory.isEmpty)
        #expect(!info.formattedOS.isEmpty)
        #expect(!info.formattedCores.isEmpty)
        #expect(!MachineInfo.uptimeString.isEmpty)
    }
}

@Suite("NetworkSampler and Totals Tests")
struct NetworkSamplerTests {
    @Test func testNetworkSnapshotTotals() {
        let snapshot = NetworkUsageSnapshot(
            rxBytesPerSecond: 1024,
            txBytesPerSecond: 2048,
            status: .stable,
            totalRxBytes: 5_000_000,
            totalTxBytes: 3_000_000
        )
        #expect(snapshot.totalRxBytes == 5_000_000)
        #expect(snapshot.totalTxBytes == 3_000_000)
        #expect(snapshot.rxBytesPerSecond == 1024)
        #expect(snapshot.txBytesPerSecond == 2048)
    }
    
    @Test func testNetworkSamplerResetTotals() {
        let sampler = NetworkSampler()
        let sample1 = sampler.sample()
        #expect(sample1.totalRxBytes == 0)
        #expect(sample1.totalTxBytes == 0)
        
        sampler.resetTotals()
        let sample2 = sampler.sample()
        #expect(sample2.totalRxBytes == 0)
        #expect(sample2.totalTxBytes == 0)
    }
}

@Suite("NetworkDiagnostics Tests")
struct NetworkDiagnosticsTests {
    @Test func testResolveLocalIP() {
        let ip = NetworkDiagnosticsService.resolveLocalIP()
        if let localIP = ip {
            #expect(!localIP.isEmpty)
            #expect(!localIP.hasPrefix("127."))
            #expect(!localIP.hasPrefix("169.254."))
        }
    }
    
    @Test func testNetworkDiagnosticsSnapshot() {
        let snapshot = NetworkDiagnosticsSnapshot(
            latencyMs: 15.5,
            jitterMs: 2.1,
            wifiRSSI: -52,
            wifiLinkRateMbps: 1200,
            interfaceName: "en0",
            localIP: "192.168.1.50",
            publicIP: "1.2.3.4",
            isInternetUp: true,
            isMeasuring: false
        )
        #expect(snapshot.localIP == "192.168.1.50")
        #expect(snapshot.publicIP == "1.2.3.4")
        #expect(snapshot.isInternetUp == true)
        #expect(snapshot.interfaceName == "en0")
    }
}

@Suite("ShelfModel Action Tests")
struct ShelfModelActionTests {
    private final class ResetBox: @unchecked Sendable {
        var called = false
    }
    
    @Test @MainActor func testResetNetworkTotalsCallback() {
        let model = ShelfModel()
        let box = ResetBox()
        model.onResetNetworkTotals = {
            box.called = true
        }
        model.resetNetworkTotals()
        #expect(box.called == true)
    }
    
    @Test @MainActor func testDynamicIslandInitialAnimationState() {
        let model = ShelfModel()
        #expect(model.isShelfPresented == false)
        #expect(model.isContentVisible == false)
        #expect(model.anchorXFraction == 0.5)
        
        // Diagnostic snapshot updates should be dropped while shelf is closed
        let dummySnapshot = DiagnosticSnapshot(
            topCPUProcesses: [
                ProcessItem(pid: 1234, name: "TestApp", bundleIdentifier: nil, ownerUID: 501, cpuUsagePercent: 50.0, memoryBytes: 100_000_000, isClosable: true, isSystemProtected: false)
            ]
        )
        model.updateDiagnosticSnapshot(dummySnapshot)
        #expect(model.diagnosticSnapshot.topCPUProcesses.isEmpty)
        
        // When presented, diagnostic snapshot updates are accepted
        model.isShelfPresented = true
        model.updateDiagnosticSnapshot(dummySnapshot)
        #expect(model.diagnosticSnapshot.topCPUProcesses.count == 1)
        
        let box = ResetBox()
        model.onCloseRequested = {
            box.called = true
        }
        model.requestClose()
        #expect(box.called == true)
    }

    @Test @MainActor func testDynamicIslandPanelConfiguration() {
        let rect = NSRect(x: 100, y: 100, width: 610, height: 740)
        let panel = DynamicIslandPanel(contentRect: rect)
        #expect(panel.isFloatingPanel == true)
        #expect(panel.level == .statusBar)
        #expect(panel.isOpaque == false)
        #expect(panel.hasShadow == false)
        #expect(panel.canBecomeKey == true)
        #expect(panel.canBecomeMain == false)
    }
}

@Suite("ProcessSkeletonView Tests")
struct ProcessSkeletonViewTests {
    @Test @MainActor func testProcessSkeletonRowViewInitialization() {
        let view = ProcessSkeletonRowView(nameWidth: 90, metricWidth: 40)
        #expect(view.nameWidth == 90)
        #expect(view.metricWidth == 40)
        
        let defaultView = ProcessSkeletonRowView()
        #expect(defaultView.nameWidth == 80)
        #expect(defaultView.metricWidth == 34)
    }
    
    @Test @MainActor func testShelfModelResetDiagnosticSnapshotState() {
        let model = ShelfModel()
        model.resetDiagnosticSnapshot()
        #expect(model.diagnosticSnapshot.isMeasuringCPUProcesses == true)
        #expect(model.diagnosticSnapshot.topCPUProcesses.isEmpty)
        #expect(model.diagnosticSnapshot.topMemoryProcesses.isEmpty)
    }
}

@Suite("DynamicIslandTransition Tests")
struct DynamicIslandTransitionTests {
    @Test @MainActor func testShelfControllerToggleLifecycle() {
        let coordinator = MonitoringCoordinator()
        let model = ShelfModel()
        let controller = ShelfController(model: model, coordinator: coordinator)
        
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 500, width: 200, height: 22),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let button = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
        window.contentView?.addSubview(button)
        
        // Initial closed state
        #expect(controller.isVisible == false)
        #expect(model.isShelfPresented == false)
        #expect(model.isContentVisible == false)
        
        // Show shelf
        controller.show(relativeTo: button)
        #expect(controller.panel.isVisible == true)
        #expect(coordinator.mode == .diagnostic)
        
        // Simulate animation completion
        model.isShelfPresented = true
        model.isContentVisible = true
        #expect(controller.isVisible == true)
        
        // Close shelf: diagnostics must stop immediately
        controller.close()
        #expect(model.isShelfPresented == false)
        #expect(model.isContentVisible == false)
        #expect(coordinator.mode == .passive)
        
        // Fast re-open mid-flight while panel is still visible
        controller.show(relativeTo: button)
        #expect(coordinator.mode == .diagnostic)
        #expect(controller.panel.isVisible == true)
        
        // Final close
        controller.close()
        coordinator.stop()
    }
}

@Suite("HealthStatusIndicator Tests")
struct HealthStatusIndicatorTests {
    @Test @MainActor func testCPUStatusIndicator() {
        let normal = HealthStatusIndicator.cpu(status: .normal)
        #expect(normal.options.count == 3)
        #expect(normal.selectedIndex == 0)
        #expect(normal.options[0].label == "Normal")
        #expect(normal.options[1].label == "Heavy")
        #expect(normal.options[2].label == "Critical")
        
        let heavy = HealthStatusIndicator.cpu(status: .heavy)
        #expect(heavy.selectedIndex == 1)
        
        let critical = HealthStatusIndicator.cpu(status: .critical)
        #expect(critical.selectedIndex == 2)
    }
    
    @Test @MainActor func testNetworkStatusIndicator() {
        let stable = HealthStatusIndicator.network(status: .stable)
        #expect(stable.options.count == 3)
        #expect(stable.selectedIndex == 0)
        #expect(stable.options[0].label == "Stable")
        #expect(stable.options[1].label == "Degraded")
        #expect(stable.options[2].label == "Offline")
        
        let degraded = HealthStatusIndicator.network(status: .degraded)
        #expect(degraded.selectedIndex == 1)
        
        let offline = HealthStatusIndicator.network(status: .offline)
        #expect(offline.selectedIndex == 2)
    }
    
    @Test @MainActor func testIndicatorAlignment() {
        let cpu = HealthStatusIndicator.cpu(status: .normal, alignment: .trailing)
        #expect(cpu.alignment == .trailing)
        let memory = HealthStatusIndicator.memory(status: .heavy, alignment: .trailing)
        #expect(memory.alignment == .trailing)
        let network = HealthStatusIndicator.network(status: .stable, alignment: .trailing)
        #expect(network.alignment == .trailing)
    }
    
    @Test @MainActor func testStatusItemDismissalRecording() {
        let model = ShelfModel()
        let coordinator = MonitoringCoordinator()
        let controller = ShelfController(model: model, coordinator: coordinator)
        
        #expect(controller.lastDismissalTime == .distantPast)
        controller.recordDismissal()
        #expect(Date().timeIntervalSince(controller.lastDismissalTime) < 1.0)
    }
}

@Suite("Sleep Wake Lifecycle Tests")
struct SleepWakeLifecycleTests {
    @Test func testHistoryPreservedAcrossSleepWithDiscontinuity() {
        let store = HistoryStore(capacity: 90)
        
        // Push 10 pre-sleep samples
        for i in 1...10 {
            store.append(cpu: Double(i * 5), memory: 40.0, rx: 1000.0, tx: 500.0)
        }
        #expect(store.samples().count == 10)
        #expect(store.activeCPUHistory().count == 10)
        #expect(store.cpuHistory().allSatisfy { $0 != nil })
        
        // System sleeps and wakes: insert discontinuity
        store.markDiscontinuity()
        
        // Count should be 11 (10 pre-sleep + 1 discontinuity gap)
        #expect(store.samples().count == 11)
        let history = store.cpuHistory()
        #expect(history.count == 11)
        #expect(history[10] == nil) // Discontinuity gap slot is nil
        #expect(history[0] == 5.0)   // Pre-sleep samples preserved
        #expect(history[9] == 50.0)
        
        // Post-wake first sample arrives
        store.append(cpu: 12.0, memory: 41.0, rx: 2000.0, tx: 800.0)
        
        #expect(store.samples().count == 12)
        let postWakeHistory = store.cpuHistory()
        #expect(postWakeHistory.count == 12)
        #expect(postWakeHistory[9] == 50.0) // Last pre-sleep
        #expect(postWakeHistory[10] == nil) // Gap
        #expect(postWakeHistory[11] == 12.0) // First post-wake
        
        // Duplicate consecutive discontinuities are prevented
        store.markDiscontinuity()
        #expect(store.samples().count == 13)
        store.markDiscontinuity()
        #expect(store.samples().count == 13) // Not duplicated
    }
    
    @Test func testDiscontinuityNotInsertedOnEmptyHistory() {
        let store = HistoryStore(capacity: 90)
        #expect(store.samples().isEmpty)
        store.markDiscontinuity()
        #expect(store.samples().isEmpty)
    }
    
    @Test func testCoordinatorSleepWakePreservesHistory() {
        let coordinator = MonitoringCoordinator()
        let store = coordinator.historyStore
        
        // Add pre-sleep samples
        store.append(cpu: 25.0, memory: 50.0, rx: 5000, tx: 2000)
        store.append(cpu: 30.0, memory: 50.0, rx: 6000, tx: 2500)
        #expect(store.samples().count == 2)
        
        // Sleep stops sampling
        coordinator.handleSystemSleep()
        #expect(store.samples().count == 2)
        
        // Wake preserves history and inserts discontinuity
        coordinator.handleSystemWake()
        #expect(store.samples().count == 3)
        #expect(store.cpuHistory()[2] == nil)
        #expect(store.cpuHistory()[0] == 25.0)
        #expect(store.cpuHistory()[1] == 30.0)
        
        coordinator.stop()
    }
    
    @Test func testNoBogusSpikesOnWakeBaselines() {
        let cpu = CPUSampler()
        let network = NetworkSampler()
        
        // Establish initial baselines
        _ = cpu.sample()
        _ = network.sample()
        
        // Simulate sleep/wake baseline resets
        cpu.resetBaseline()
        _ = cpu.sample() // Establishes new baseline immediately without spike
        
        network.resetBaseline()
        _ = network.sample() // Establishes new network baseline
        
        // Next sample produces clean delta, not accumulated jump
        let cpuSnapshot = cpu.sample()
        #expect(cpuSnapshot.totalUsage >= 0 && cpuSnapshot.totalUsage <= 100)
        
        let netSnapshot = network.sample()
        #expect(netSnapshot.rxBytesPerSecond >= 0)
        #expect(netSnapshot.txBytesPerSecond >= 0)
    }
}

@Suite("Fan and Thermal Capability Tests")
struct FanAndThermalCapabilityTests {
    @Test func testAllSixFanCapabilityStatesFormatting() {
        // State 1: Measuring
        #expect(TuckedFormatter.formatFanCapability(.measuring) == "Measuring…")
        
        // State 2: Fanless
        #expect(TuckedFormatter.formatFanCapability(.fanless) == "Fanless")
        
        // State 3: Zero RPM (single and dual)
        #expect(TuckedFormatter.formatFanCapability(.zeroRPM(rpms: [0])) == "0 RPM")
        #expect(TuckedFormatter.formatFanCapability(.zeroRPM(rpms: [0, 0])) == "0 / 0 RPM")
        
        // State 4: Active RPM
        #expect(TuckedFormatter.formatFanCapability(.active(rpms: [1840])) == "1840 RPM")
        #expect(TuckedFormatter.formatFanCapability(.active(rpms: [1840, 1920])) == "1840 / 1920 RPM")
        
        // State 5: Not Found (known fans, sensor unreadable)
        #expect(TuckedFormatter.formatFanCapability(.notFound) == "Not Found")
        
        // State 6: Indeterminate
        #expect(TuckedFormatter.formatFanCapability(.indeterminate) == "\u{2014}")
    }
    
    @Test func testThermalSnapshotIndependentStates() {
        // CPU temp active with fan measuring
        let s1 = ThermalSnapshot(
            cpuTemperatureCelsius: 52,
            temperatureState: .active(celsius: 52),
            fanState: .measuring,
            fans: []
        )
        #expect(s1.cpuTemperatureCelsius == 52)
        #expect(s1.temperatureState == .active(celsius: 52))
        #expect(s1.fanState == .measuring)
        #expect(TuckedFormatter.formatFanCapability(s1.fanState) == "Measuring…")
        #expect(TuckedFormatter.formatTemperature(s1.cpuTemperatureCelsius) == "52°C")
        
        // CPU temp unavailable with fans active
        let s2 = ThermalSnapshot(
            cpuTemperatureCelsius: nil,
            temperatureState: .unavailable,
            fanState: .active(rpms: [2100]),
            fans: [FanReading(id: 0, displayName: "Fan 1", rpm: 2100)]
        )
        #expect(s2.temperatureState == .unavailable)
        #expect(s2.fanState == .active(rpms: [2100]))
        #expect(TuckedFormatter.formatFanCapability(s2.fanState) == "2100 RPM")
        
        // Fanless machine
        let s3 = ThermalSnapshot(
            cpuTemperatureCelsius: 45,
            temperatureState: .active(celsius: 45),
            fanState: .fanless,
            fans: []
        )
        #expect(s3.fanState == .fanless)
        #expect(s3.state == .fanless)
        #expect(TuckedFormatter.formatFanCapability(s3.fanState) == "Fanless")
        
        // Fans not found
        let s4 = ThermalSnapshot(
            cpuTemperatureCelsius: 60,
            temperatureState: .active(celsius: 60),
            fanState: .notFound,
            fans: []
        )
        #expect(s4.fanState == .notFound)
        #expect(TuckedFormatter.formatFanCapability(s4.fanState) == "Not Found")
        
        // Fan capability indeterminate
        let s5 = ThermalSnapshot(
            cpuTemperatureCelsius: nil,
            temperatureState: .unavailable,
            fanState: .indeterminate,
            fans: []
        )
        #expect(s5.fanState == .indeterminate)
        #expect(TuckedFormatter.formatFanCapability(s5.fanState) == "\u{2014}")
    }
    
    @Test func testMachineInfoFanHardwareEvidence() {
        // Fanless Air models
        let air1 = MachineInfo(
            model: "MacBookAir10,1",
            chip: "Apple M1",
            coreCount: 8,
            memoryBytes: 8589934592,
            osVersion: "14.5",
            osBuild: "23F79",
            architecture: "arm64"
        )
        #expect(air1.fanHardwareEvidence == .fanless)
        
        let air2 = MachineInfo(
            model: "Mac14,2",
            chip: "Apple M2",
            coreCount: 8,
            memoryBytes: 8589934592,
            osVersion: "14.5",
            osBuild: "23F79",
            architecture: "arm64"
        )
        #expect(air2.fanHardwareEvidence == .fanless)
        
        // Hardware with fans
        let pro = MachineInfo(
            model: "MacBookPro18,1",
            chip: "Apple M1 Pro",
            coreCount: 10,
            memoryBytes: 17179869184,
            osVersion: "14.5",
            osBuild: "23F79",
            architecture: "arm64"
        )
        #expect(pro.fanHardwareEvidence == .hasFans)
        
        let mini = MachineInfo(
            model: "Macmini9,1",
            chip: "Apple M1",
            coreCount: 8,
            memoryBytes: 8589934592,
            osVersion: "14.5",
            osBuild: "23F79",
            architecture: "arm64"
        )
        #expect(mini.fanHardwareEvidence == .hasFans)
        
        let neo = MachineInfo(
            model: "MacBookNeo1,1",
            chip: "Apple A18 Pro",
            coreCount: 6,
            memoryBytes: 8589934592,
            osVersion: "15.0",
            osBuild: "24A100",
            architecture: "arm64"
        )
        #expect(neo.fanHardwareEvidence == .fanless)
        
        // Indeterminate
        let unknown = MachineInfo(
            model: "VirtualMac2,1",
            chip: "Virtual CPU",
            coreCount: 4,
            memoryBytes: 4294967296,
            osVersion: "14.5",
            osBuild: "23F79",
            architecture: "arm64"
        )
        #expect(unknown.fanHardwareEvidence == .indeterminate)
    }
    
    @Test func testBoundedDiscoveryNeverStuckInMeasuring() {
        let provider = ThermalProvider()
        
        // Fanless hardware resolves immediately without retry
        let snapFanless = provider.sample(hardwareEvidence: .fanless)
        #expect(snapFanless.fanState == .fanless)
        
        provider.reset()
        
        // Indeterminate hardware: attempts 1..3
        _ = provider.sample(hardwareEvidence: .indeterminate)
        _ = provider.sample(hardwareEvidence: .indeterminate)
        let s3 = provider.sample(hardwareEvidence: .indeterminate)
        
        // After maxDiscoveryAttempts, fanState must never be measuring
        #expect(s3.fanState != .measuring)
        
        // If discovery failed without reading fans, it must never fake fanless or zero RPM
        if s3.fans.isEmpty {
            #expect(s3.fanState != .fanless)
            #expect(s3.fanState == .notFound || s3.fanState == .indeterminate)
        }
        
        provider.stop()
    }
}



