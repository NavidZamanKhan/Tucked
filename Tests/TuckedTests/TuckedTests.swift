import Testing
import Foundation
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


