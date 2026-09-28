import Foundation
import IOKit

/// Read-only AppleSMC interface for CPU temperature and fan speed.
/// STRICT INVARIANT: Contains zero write selectors or commands.
public final class SMCReader: @unchecked Sendable {
    private struct SMCVersion {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    private struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    private struct SMCKeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    private struct SMCKeyData {
        var key: UInt32 = 0
        var vers = SMCVersion()
        var pLimitData = SMCPLimitData()
        var keyInfo = SMCKeyInfo()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
        ) = (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    private enum SMCCommand: UInt8 {
        case readBytes = 5
        case readKeyInfo = 9
    }

    private var connection: io_connect_t = 0
    private var isConnected: Bool = false
    private let lock = NSLock()
    
    // Cached discovered keys
    private var validatedCPUKeys: [String] = []
    private var discoveredFanCount: Int?
    private var isDiscovered: Bool = false
    private var lastKnownFanRPMs: [Int: Int] = [:]

    public init() {}

    deinit {
        close()
    }

    public func open() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isConnected else { return true }
        
        let matching = IOServiceMatching("AppleSMC")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else {
            TuckedLog.thermal.error("AppleSMC service not found")
            return false
        }
        defer { IOObjectRelease(service) }
        
        var conn: io_connect_t = 0
        let status = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard status == kIOReturnSuccess else {
            TuckedLog.thermal.error("Failed to open AppleSMC: \(status)")
            return false
        }
        
        self.connection = conn
        self.isConnected = true
        return true
    }

    public func close() {
        lock.lock()
        defer { lock.unlock() }
        
        if isConnected && connection != 0 {
            IOServiceClose(connection)
            connection = 0
            isConnected = false
        }
    }

    /// Discovers supported CPU temperature keys and fan configuration.
    public func discoverSensors() {
        guard open() else { return }
        lock.lock()
        defer { lock.unlock() }
        
        // 1. Discover Fan Count
        if let countVal = readNumericKey(SensorCatalog.fanCountKey) {
            discoveredFanCount = Int(countVal)
        } else if readNumericKey(SensorCatalog.fanActualRPMKey(index: 0)) != nil {
            discoveredFanCount = 1
        }
        
        // 2. Discover Valid CPU Temperature Keys
        if validatedCPUKeys.isEmpty {
            var workingKeys: [String] = []
            for key in SensorCatalog.knownCPUTemperatureKeys {
                if let temp = readTemperatureKey(key), temp > 0, temp < 130 {
                    workingKeys.append(key)
                }
            }
            validatedCPUKeys = workingKeys
        }
        isDiscovered = true
        
        TuckedLog.thermal.info("Thermal discovery complete: fans=\(String(describing: self.discoveredFanCount)), cpuKeys=\(self.validatedCPUKeys.count)")
    }
    
    public func resetDiscovery() {
        lock.lock()
        defer { lock.unlock() }
        isDiscovered = false
        discoveredFanCount = nil
    }

    /// Reads representative CPU temperature (average of validated CPU sensor keys in Celsius).
    public func readCPUTemperature() -> Int? {
        guard open() else { return nil }
        lock.lock()
        defer { lock.unlock() }
        
        if !isDiscovered {
            lock.unlock()
            discoverSensors()
            lock.lock()
        }
        
        guard !validatedCPUKeys.isEmpty else {
            // Attempt fallback scan over known keys
            for key in SensorCatalog.knownCPUTemperatureKeys {
                if let temp = readTemperatureKey(key), temp > 15, temp < 115 {
                    return Int(round(temp))
                }
            }
            return nil
        }
        
        var sum: Double = 0
        var count = 0
        for key in validatedCPUKeys {
            if let val = readTemperatureKey(key), val > 10, val < 125 {
                sum += val
                count += 1
            }
        }
        
        guard count > 0 else { return nil }
        return Int(round(sum / Double(count)))
    }

    /// Reads fan RPM readings. Distinguishes fanless hardware from 0 RPM fans and unlocatable sensors.
    public func readFans(hardwareEvidence: FanHardwareEvidence = .indeterminate) -> (readings: [FanReading], isFanless: Bool, fanCount: Int?) {
        guard open() else { return ([], false, nil) }
        lock.lock()
        defer { lock.unlock() }
        
        if hardwareEvidence == .fanless {
            return ([], true, 0)
        }
        
        if !isDiscovered || discoveredFanCount == nil {
            lock.unlock()
            discoverSensors()
            lock.lock()
        }
        
        // Fallback: If FNum was nil, check if F0Ac responds or model confirms fans
        if discoveredFanCount == nil {
            if readNumericKey(SensorCatalog.fanActualRPMKey(index: 0)) != nil {
                discoveredFanCount = 1
            } else if hardwareEvidence == .hasFans {
                discoveredFanCount = 1
            }
        }
        
        guard let count = discoveredFanCount else {
            return ([], false, nil)
        }
        
        if count == 0 {
            return ([], true, 0)
        }
        
        var readings: [FanReading] = []
        for i in 0..<count {
            let key = SensorCatalog.fanActualRPMKey(index: i)
            if let rpm = readNumericKey(key) {
                let rounded = max(0, Int(round(rpm)))
                lastKnownFanRPMs[i] = rounded
                readings.append(FanReading(id: i, displayName: "Fan \(i + 1)", rpm: rounded))
            } else if let cached = lastKnownFanRPMs[i] {
                readings.append(FanReading(id: i, displayName: "Fan \(i + 1)", rpm: cached))
            }
            // Do not fake 0 RPM if reading fails and there is no cached verified reading
        }
        
        return (readings, false, count)
    }

    // MARK: - Low-Level Read-Only Operations

    private func readTemperatureKey(_ key: String) -> Double? {
        guard let keyInfo = getKeyInfo(key) else { return nil }
        guard let data = readBytes(key: key, size: keyInfo.dataSize) else { return nil }
        
        let typeCode = keyInfo.dataType
        
        // sp78: signed fixed point (8 bits integer, 8 bits fraction)
        if typeCode == fourCCToUInt32("sp78") && data.count >= 2 {
            let raw = (Int16(data[0]) << 8) | Int16(data[1])
            return Double(raw) / 256.0
        }
        // flt: 32-bit float (Apple Silicon little-endian IEEE 754 with big-endian fallback)
        if typeCode == fourCCToUInt32("flt ") && data.count >= 4 {
            let rawLE = UInt32(data[0]) | (UInt32(data[1]) << 8) | (UInt32(data[2]) << 16) | (UInt32(data[3]) << 24)
            let valLE = Float(bitPattern: rawLE)
            if !valLE.isNaN && !valLE.isInfinite && valLE > 0 && valLE < 150 {
                return Double(valLE)
            }
            let rawBE = (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16) | (UInt32(data[2]) << 8) | UInt32(data[3])
            let valBE = Float(bitPattern: rawBE)
            if !valBE.isNaN && !valBE.isInfinite && valBE > 0 && valBE < 150 {
                return Double(valBE)
            }
        }
        // fpe2: unsigned fixed point (14 bits integer, 2 bits fraction)
        if typeCode == fourCCToUInt32("fpe2") && data.count >= 2 {
            let raw = (UInt16(data[0]) << 8) | UInt16(data[1])
            return Double(raw) / 4.0
        }
        
        return nil
    }

    private func readNumericKey(_ key: String) -> Double? {
        guard let keyInfo = getKeyInfo(key) else { return nil }
        guard let data = readBytes(key: key, size: keyInfo.dataSize) else { return nil }
        
        let typeCode = keyInfo.dataType
        
        if typeCode == fourCCToUInt32("ui8 ") && !data.isEmpty {
            return Double(data[0])
        }
        if typeCode == fourCCToUInt32("ui16") && data.count >= 2 {
            let val = (UInt16(data[0]) << 8) | UInt16(data[1])
            return Double(val)
        }
        if typeCode == fourCCToUInt32("ui32") && data.count >= 4 {
            let val = (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16) | (UInt32(data[2]) << 8) | UInt32(data[3])
            return Double(val)
        }
        if typeCode == fourCCToUInt32("fpe2") && data.count >= 2 {
            let raw = (UInt16(data[0]) << 8) | UInt16(data[1])
            return Double(raw) / 4.0
        }
        if typeCode == fourCCToUInt32("sp78") && data.count >= 2 {
            let raw = (Int16(data[0]) << 8) | Int16(data[1])
            return Double(raw) / 256.0
        }
        if typeCode == fourCCToUInt32("flt ") && data.count >= 4 {
            let rawLE = UInt32(data[0]) | (UInt32(data[1]) << 8) | (UInt32(data[2]) << 16) | (UInt32(data[3]) << 24)
            let valLE = Float(bitPattern: rawLE)
            if !valLE.isNaN && !valLE.isInfinite && valLE >= 0 && valLE < 20000 {
                return Double(valLE)
            }
            let rawBE = (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16) | (UInt32(data[2]) << 8) | UInt32(data[3])
            let valBE = Float(bitPattern: rawBE)
            if !valBE.isNaN && !valBE.isInfinite && valBE >= 0 && valBE < 20000 {
                return Double(valBE)
            }
        }
        
        return nil
    }

    private func getKeyInfo(_ key: String) -> SMCKeyInfo? {
        var inputStructure = SMCKeyData()
        var outputStructure = SMCKeyData()
        
        inputStructure.key = fourCCToUInt32(key)
        inputStructure.data8 = SMCCommand.readKeyInfo.rawValue
        
        let result = callSMC(input: &inputStructure, output: &outputStructure)
        guard result == kIOReturnSuccess, outputStructure.result == 0 else {
            return nil
        }
        
        return outputStructure.keyInfo
    }

    private func readBytes(key: String, size: UInt32) -> [UInt8]? {
        var inputStructure = SMCKeyData()
        var outputStructure = SMCKeyData()
        
        inputStructure.key = fourCCToUInt32(key)
        inputStructure.keyInfo.dataSize = size
        inputStructure.data8 = SMCCommand.readBytes.rawValue
        
        let result = callSMC(input: &inputStructure, output: &outputStructure)
        guard result == kIOReturnSuccess, outputStructure.result == 0 else {
            return nil
        }
        
        return withUnsafeBytes(of: &outputStructure.bytes) { rawBuffer in
            let count = min(Int(size), 32)
            return Array(rawBuffer.prefix(count))
        }
    }

    private func callSMC(input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        guard isConnected && connection != 0 else {
            return kIOReturnNotOpen
        }
        
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride
        
        return IOConnectCallStructMethod(
            connection,
            2, // AppleSMC method selector 2
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }

    private func fourCCToUInt32(_ str: String) -> UInt32 {
        var res: UInt32 = 0
        let utf8 = Array(str.utf8.prefix(4))
        for byte in utf8 {
            res = (res << 8) | UInt32(byte)
        }
        return res
    }
}
