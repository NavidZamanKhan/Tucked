import Foundation

public enum CPUHealthStatus: String, Sendable, CaseIterable {
    case normal = "NORMAL"
    case heavy = "HEAVY"
    case critical = "CRITICAL"
}

public enum MemoryHealthStatus: String, Sendable, CaseIterable {
    case normal = "NORMAL"
    case heavy = "HEAVY"
    case critical = "CRITICAL"
}

public enum NetworkHealthStatus: String, Sendable, CaseIterable {
    case checking = "CHECKING"
    case stable = "STABLE"
    case degraded = "DEGRADED"
    case poor = "POOR"
    case offline = "OFFLINE"
}

public enum ThermalState: Sendable {
    case supported
    case fanless
    case unavailable
}

public struct FanReading: Sendable, Identifiable {
    public let id: Int
    public let displayName: String
    public let rpm: Int
    
    public init(id: Int, displayName: String, rpm: Int) {
        self.id = id
        self.displayName = displayName
        self.rpm = rpm
    }
}

public struct CPUUsageSnapshot: Sendable {
    public let totalUsage: Double
    public let userUsage: Double
    public let systemUsage: Double
    public let idleUsage: Double
    public let status: CPUHealthStatus
    
    public init(
        totalUsage: Double = 0,
        userUsage: Double = 0,
        systemUsage: Double = 0,
        idleUsage: Double = 100,
        status: CPUHealthStatus = .normal
    ) {
        self.totalUsage = totalUsage
        self.userUsage = userUsage
        self.systemUsage = systemUsage
        self.idleUsage = idleUsage
        self.status = status
    }
}

public struct MemoryUsageSnapshot: Sendable {
    public let usedBytes: UInt64
    public let totalPhysicalBytes: UInt64
    public let swapBytes: UInt64
    public let compressedBytes: UInt64
    public let usedPercentage: Double
    public let status: MemoryHealthStatus
    
    public var freeBytes: UInt64 {
        totalPhysicalBytes > usedBytes ? totalPhysicalBytes - usedBytes : 0
    }
    
    public init(
        usedBytes: UInt64 = 0,
        totalPhysicalBytes: UInt64 = 0,
        swapBytes: UInt64 = 0,
        compressedBytes: UInt64 = 0,
        usedPercentage: Double = 0,
        status: MemoryHealthStatus = .normal
    ) {
        self.usedBytes = usedBytes
        self.totalPhysicalBytes = totalPhysicalBytes
        self.swapBytes = swapBytes
        self.compressedBytes = compressedBytes
        self.usedPercentage = usedPercentage
        self.status = status
    }
}

public struct NetworkUsageSnapshot: Sendable {
    public let rxBytesPerSecond: Double
    public let txBytesPerSecond: Double
    public let status: NetworkHealthStatus
    
    public init(
        rxBytesPerSecond: Double = 0,
        txBytesPerSecond: Double = 0,
        status: NetworkHealthStatus = .stable
    ) {
        self.rxBytesPerSecond = rxBytesPerSecond
        self.txBytesPerSecond = txBytesPerSecond
        self.status = status
    }
}

public struct ThermalSnapshot: Sendable {
    public let cpuTemperatureCelsius: Int?
    public let fans: [FanReading]
    public let state: ThermalState
    
    public init(
        cpuTemperatureCelsius: Int? = nil,
        fans: [FanReading] = [],
        state: ThermalState = .unavailable
    ) {
        self.cpuTemperatureCelsius = cpuTemperatureCelsius
        self.fans = fans
        self.state = state
    }
}

public struct ProcessItem: Sendable, Identifiable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let bundleIdentifier: String?
    public let ownerUID: uid_t
    public let cpuUsagePercent: Double
    public let memoryBytes: UInt64
    public let isClosable: Bool
    public let isSystemProtected: Bool
    
    public init(
        pid: Int32,
        name: String,
        bundleIdentifier: String?,
        ownerUID: uid_t,
        cpuUsagePercent: Double,
        memoryBytes: UInt64,
        isClosable: Bool,
        isSystemProtected: Bool
    ) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.ownerUID = ownerUID
        self.cpuUsagePercent = cpuUsagePercent
        self.memoryBytes = memoryBytes
        self.isClosable = isClosable
        self.isSystemProtected = isSystemProtected
    }
}

public struct NetworkDiagnosticsSnapshot: Sendable {
    public let latencyMs: Double?
    public let jitterMs: Double?
    public let wifiRSSI: Int?
    public let wifiLinkRateMbps: Double?
    public let interfaceName: String?
    public let isMeasuring: Bool
    
    public init(
        latencyMs: Double? = nil,
        jitterMs: Double? = nil,
        wifiRSSI: Int? = nil,
        wifiLinkRateMbps: Double? = nil,
        interfaceName: String? = nil,
        isMeasuring: Bool = false
    ) {
        self.latencyMs = latencyMs
        self.jitterMs = jitterMs
        self.wifiRSSI = wifiRSSI
        self.wifiLinkRateMbps = wifiLinkRateMbps
        self.interfaceName = interfaceName
        self.isMeasuring = isMeasuring
    }
}

public struct SystemSnapshot: Sendable {
    public let cpu: CPUUsageSnapshot
    public let memory: MemoryUsageSnapshot
    public let network: NetworkUsageSnapshot
    public let timestamp: Date
    
    public init(
        cpu: CPUUsageSnapshot = CPUUsageSnapshot(),
        memory: MemoryUsageSnapshot = MemoryUsageSnapshot(),
        network: NetworkUsageSnapshot = NetworkUsageSnapshot(),
        timestamp: Date = Date()
    ) {
        self.cpu = cpu
        self.memory = memory
        self.network = network
        self.timestamp = timestamp
    }
}

public struct DiagnosticSnapshot: Sendable {
    public let thermal: ThermalSnapshot
    public let topCPUProcesses: [ProcessItem]
    public let topMemoryProcesses: [ProcessItem]
    public let networkDiagnostics: NetworkDiagnosticsSnapshot
    public let isMeasuringCPUProcesses: Bool
    public let timestamp: Date
    
    public init(
        thermal: ThermalSnapshot = ThermalSnapshot(),
        topCPUProcesses: [ProcessItem] = [],
        topMemoryProcesses: [ProcessItem] = [],
        networkDiagnostics: NetworkDiagnosticsSnapshot = NetworkDiagnosticsSnapshot(),
        isMeasuringCPUProcesses: Bool = false,
        timestamp: Date = Date()
    ) {
        self.thermal = thermal
        self.topCPUProcesses = topCPUProcesses
        self.topMemoryProcesses = topMemoryProcesses
        self.networkDiagnostics = networkDiagnostics
        self.isMeasuringCPUProcesses = isMeasuringCPUProcesses
        self.timestamp = timestamp
    }
}
