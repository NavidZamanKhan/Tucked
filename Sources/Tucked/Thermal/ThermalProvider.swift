import Foundation

/// Coordinates thermal data collection and provides ThermalSnapshot.
public final class ThermalProvider: @unchecked Sendable {
    private let smcReader = SMCReader()
    private let queue = DispatchQueue(label: "ai.mpiv.Tucked.Thermal", qos: .utility)
    private var lastSnapshot = ThermalSnapshot()
    private let lock = NSLock()

    public init() {}

    public func sample() -> ThermalSnapshot {
        lock.lock()
        defer { lock.unlock() }

        let cpuTemp = smcReader.readCPUTemperature()
        let fanResult = smcReader.readFans()

        let state: ThermalState
        if fanResult.isFanless {
            state = .fanless
        } else if cpuTemp != nil || !fanResult.readings.isEmpty {
            state = .supported
        } else {
            state = .unavailable
        }

        let snapshot = ThermalSnapshot(
            cpuTemperatureCelsius: cpuTemp,
            fans: fanResult.readings,
            state: state
        )

        self.lastSnapshot = snapshot
        return snapshot
    }

    public func stop() {
        smcReader.close()
    }
}
