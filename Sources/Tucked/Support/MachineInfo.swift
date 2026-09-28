import Foundation

public enum FanHardwareEvidence: Sendable, Equatable {
    case fanless
    case hasFans
    case indeterminate
}

/// Native hardware and system specification provider using read-only Darwin sysctl calls.
public struct MachineInfo: Sendable {
    public let model: String
    public let chip: String
    public let coreCount: Int
    public let memoryBytes: UInt64
    public let osVersion: String
    public let osBuild: String
    public let architecture: String
    
    public var fanHardwareEvidence: FanHardwareEvidence {
        let m = model.lowercased()
        if m.contains("air") || m.contains("neo") || m == "mac14,2" || m == "mac14,15" || m == "mac15,2" || m == "mac15,12" || m == "mac15,13" {
            return .fanless
        }
        if m.contains("pro") || m.contains("mini") || m.contains("studio") || m.contains("imac") {
            return .hasFans
        }
        if m == "mac13,1" || m == "mac13,2" || m == "mac14,3" || m == "mac14,5" || m == "mac14,6" ||
           m == "mac14,7" || m == "mac14,8" || m == "mac14,9" || m == "mac14,10" || m == "mac14,12" ||
           m == "mac14,13" || m == "mac14,14" || m.hasPrefix("mac15,") || m.hasPrefix("mac16,") ||
           m.hasPrefix("mac17,") || m.hasPrefix("mac18,") {
            return .hasFans
        }
        return .indeterminate
    }
    
    public var formattedMemory: String {
        TuckedFormatter.formatBytes(memoryBytes) + " Unified Memory"
    }
    
    public var formattedOS: String {
        osBuild.isEmpty ? "macOS \(osVersion)" : "macOS \(osVersion) (\(osBuild))"
    }
    
    public var formattedCores: String {
        "\(coreCount) Cores"
    }
    
    public static var uptimeString: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    public static let current: MachineInfo = {
        let model = sysctlString("hw.model") ?? "Mac"
        let chip = sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon"
        let cores = sysctlInt("hw.physicalcpu") ?? sysctlInt("hw.ncpu") ?? 8
        let mem = sysctlUInt64("hw.memsize") ?? 0
        let osVer = sysctlString("kern.osproductversion") ?? ProcessInfo.processInfo.operatingSystemVersionString
        let osBuild = sysctlString("kern.osversion") ?? ""
        
        return MachineInfo(
            model: model,
            chip: chip,
            coreCount: cores,
            memoryBytes: mem,
            osVersion: osVer,
            osBuild: osBuild,
            architecture: "arm64"
        )
    }()
    
    private static func sysctlString(_ name: String) -> String? {
        var size: Int = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return buffer.withUnsafeBufferPointer { ptr in
            ptr.baseAddress.map { String(cString: $0) }
        }
    }
    
    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }
    
    private static func sysctlUInt64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}
