import Foundation

/// Formatter utilities for compact menu bar and shelf metrics.
public enum TuckedFormatter {
    /// Deconstructs rate into numeric value and unit for custom typographical styling.
    public static func menuBarRateComponents(_ bytesPerSecond: Double) -> (value: String, unit: String) {
        guard bytesPerSecond > 0, !bytesPerSecond.isNaN, !bytesPerSecond.isInfinite else {
            return ("0", "K")
        }
        
        let b = bytesPerSecond
        if b < 1000 {
            return ("\(Int(b))", "B")
        } else if b < 1_000_000 {
            let kb = b / 1000.0
            if kb < 10 {
                return (String(format: "%.0f", kb), "K")
            } else {
                return ("\(Int(round(kb)))", "K")
            }
        } else if b < 1_000_000_000 {
            let mb = b / 1_000_000.0
            if mb < 10 {
                return (String(format: "%.1f", mb), "M")
            } else {
                return ("\(Int(round(mb)))", "M")
            }
        } else {
            let gb = b / 1_000_000_000.0
            return (String(format: "%.1f", gb), "G")
        }
    }

    /// Compact menu bar rate formatting (e.g. 0K, 912B, 7K, 840K, 1.2M, 24M, 1.1G).
    public static func formatMenuBarRate(_ bytesPerSecond: Double) -> String {
        let (val, unit) = menuBarRateComponents(bytesPerSecond)
        return "\(val)\(unit)"
    }
    
    /// Panel network throughput rate formatting (e.g. 7 KB/s, 1.2 MB/s).
    public static func formatPanelRate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0, !bytesPerSecond.isNaN, !bytesPerSecond.isInfinite else {
            return "0 KB/s"
        }
        
        let b = bytesPerSecond
        if b < 1000 {
            return "\(Int(b)) B/s"
        } else if b < 1_000_000 {
            let kb = b / 1000.0
            return "\(Int(round(kb))) KB/s"
        } else if b < 1_000_000_000 {
            let mb = b / 1_000_000.0
            if mb < 10 {
                return String(format: "%.1f MB/s", mb)
            } else {
                return "\(Int(round(mb))) MB/s"
            }
        } else {
            let gb = b / 1_000_000_000.0
            return String(format: "%.1f GB/s", gb)
        }
    }
    
    /// Memory size formatting in decimal GB / MB (e.g. 12.3 GB, 500 MB).
    public static func formatBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1_000_000 {
            return "\(Int(round(b / 1000.0))) KB"
        } else if b < 1_000_000_000 {
            return "\(Int(round(b / 1_000_000.0))) MB"
        } else {
            let gb = b / 1_000_000_000.0
            return String(format: "%.1f GB", gb)
        }
    }
    
    /// Monospaced integer percentage formatting (0-100).
    public static func formatPercent(_ value: Double) -> String {
        guard !value.isNaN && !value.isInfinite else { return "0%" }
        let clamped = max(0, min(100, Int(round(value))))
        return "\(clamped)%"
    }
    
    /// Formatted temperature (integer Celsius, e.g. 54°C).
    public static func formatTemperature(_ celsius: Int?) -> String {
        guard let celsius else { return "-" }
        return "\(celsius)°C"
    }
    
    /// Formatted fan speed.
    public static func formatFanRPM(isFanless: Bool, rpms: [Int]) -> String {
        if isFanless {
            return "Fanless"
        }
        guard !rpms.isEmpty else {
            return "-"
        }
        if rpms.count == 1 {
            return "\(rpms[0]) RPM"
        } else {
            let joined = rpms.map { "\($0)" }.joined(separator: " / ")
            return "\(joined) RPM"
        }
    }
}
