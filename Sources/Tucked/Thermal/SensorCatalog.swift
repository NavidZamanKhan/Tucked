import Foundation

/// Curated Apple Silicon sensor keys and fan keys.
public enum SensorCatalog {
    /// Known CPU cluster/die temperature keys across Apple Silicon generations (M1 through M5).
    public static let knownCPUTemperatureKeys: [String] = [
        // M5 family
        "Tp00", "Tp04", "Tp08", "Tp0C", "Tp12", "Tp16",
        // M4 family
        "Te05", "Te0S", "Te09", "Te0H",
        // M3 family
        "Tf0A", "Tf0B", "Tf0D", "Tf0E",
        // M2 family
        "Tp1h", "Tp1t", "Tp1p", "Tp1l",
        // M1 family
        "Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0E",
        // Intel Mac CPU core/die keys
        "TC0P", "TC0D", "TC0E", "TC0F",
        // Generic SoC / Chip thermal fallback
        "TCHP"
    ]
    
    /// SMC key for number of fans.
    public static let fanCountKey = "FNum"
    
    /// Helper to get SMC key for fan actual RPM by index (e.g. F0Ac, F1Ac).
    public static func fanActualRPMKey(index: Int) -> String {
        return String(format: "F%dAc", index)
    }
}
