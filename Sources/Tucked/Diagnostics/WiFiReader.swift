import Foundation
import CoreWLAN

/// Reads Wi-Fi telemetry (RSSI and transmit rate) using CoreWLAN without requesting location or scanning.
public final class WiFiReader: @unchecked Sendable {
    public init() {}
    
    public func read() -> (rssi: Int?, linkRateMbps: Double?, interfaceName: String?) {
        let client = CWWiFiClient.shared()
        guard let interface = client.interface() else {
            return (nil, nil, nil)
        }
        
        let ifName = interface.interfaceName
        let rssiRaw = interface.rssiValue()
        let rateRaw = interface.transmitRate()
        
        // Zero in CoreWLAN getters often represents an error/unconnected state
        let rssi: Int? = (rssiRaw != 0 && rssiRaw > -120 && rssiRaw < 0) ? rssiRaw : nil
        let linkRate: Double? = (rateRaw > 0) ? rateRaw : nil
        
        return (rssi, linkRate, ifName)
    }
}
