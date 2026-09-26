import Foundation
import os

/// Structured logging categories for Tucked subsystems.
public enum TuckedLog {
    public static let app = Logger(subsystem: "ai.mpiv.Tucked", category: "App")
    public static let statusItem = Logger(subsystem: "ai.mpiv.Tucked", category: "StatusItem")
    public static let sampling = Logger(subsystem: "ai.mpiv.Tucked", category: "Sampling")
    public static let cpu = Logger(subsystem: "ai.mpiv.Tucked", category: "CPU")
    public static let thermal = Logger(subsystem: "ai.mpiv.Tucked", category: "Thermal")
    public static let memory = Logger(subsystem: "ai.mpiv.Tucked", category: "Memory")
    public static let network = Logger(subsystem: "ai.mpiv.Tucked", category: "Network")
    public static let process = Logger(subsystem: "ai.mpiv.Tucked", category: "Process")
    public static let termination = Logger(subsystem: "ai.mpiv.Tucked", category: "Termination")
    public static let ui = Logger(subsystem: "ai.mpiv.Tucked", category: "UI")
    public static let performance = Logger(subsystem: "ai.mpiv.Tucked", category: "Performance")
}
