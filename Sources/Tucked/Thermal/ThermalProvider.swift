import Foundation

/// Coordinates thermal data collection and provides ThermalSnapshot.
public final class ThermalProvider: @unchecked Sendable {
    private let smcReader = SMCReader()
    private let queue = DispatchQueue(label: "ai.mpiv.Tucked.Thermal", qos: .utility)
    private var lastSnapshot = ThermalSnapshot()
    private let lock = NSLock()

    // Bounded discovery retry tracking
    private var fanDiscoveryAttempts: Int = 0
    private var tempDiscoveryAttempts: Int = 0
    public static let maxDiscoveryAttempts: Int = 3

    public init() {}

    public func sample(hardwareEvidence: FanHardwareEvidence = MachineInfo.current.fanHardwareEvidence) -> ThermalSnapshot {
        lock.lock()
        defer { lock.unlock() }

        // 1. CPU Temperature (Independent)
        let cpuTemp = smcReader.readCPUTemperature()
        let tempState: TemperatureCapabilityState
        if let temp = cpuTemp {
            tempState = .active(celsius: temp)
            tempDiscoveryAttempts = 0
        } else {
            tempDiscoveryAttempts += 1
            if tempDiscoveryAttempts < Self.maxDiscoveryAttempts {
                tempState = .measuring
            } else {
                tempState = .unavailable
            }
        }

        // 2. Fan Capability (Independent)
        let fanResult = smcReader.readFans(hardwareEvidence: hardwareEvidence)
        let fanState: FanCapabilityState

        if fanResult.isFanless {
            fanState = .fanless
            fanDiscoveryAttempts = 0
        } else if !fanResult.readings.isEmpty {
            fanDiscoveryAttempts = 0
            let rpms = fanResult.readings.map { $0.rpm }
            if rpms.contains(where: { $0 > 0 }) {
                fanState = .active(rpms: rpms)
            } else {
                fanState = .zeroRPM(rpms: rpms)
            }
        } else {
            fanDiscoveryAttempts += 1
            if fanDiscoveryAttempts < Self.maxDiscoveryAttempts {
                fanState = .measuring
            } else {
                // Bounded discovery exhausted: never convert failure to Fanless or 0 RPM
                if (fanResult.fanCount != nil && fanResult.fanCount! > 0) || hardwareEvidence == .hasFans {
                    fanState = .notFound
                } else {
                    fanState = .indeterminate
                }
            }
        }

        let snapshot = ThermalSnapshot(
            cpuTemperatureCelsius: cpuTemp,
            temperatureState: tempState,
            fanState: fanState,
            fans: fanResult.readings
        )

        self.lastSnapshot = snapshot
        return snapshot
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        fanDiscoveryAttempts = 0
        tempDiscoveryAttempts = 0
        smcReader.resetDiscovery()
    }

    public func stop() {
        lock.lock()
        fanDiscoveryAttempts = 0
        tempDiscoveryAttempts = 0
        lock.unlock()
        smcReader.close()
    }
}
