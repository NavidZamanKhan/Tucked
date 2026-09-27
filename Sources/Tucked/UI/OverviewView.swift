import SwiftUI

/// Canonical overview monitoring surface for Tucked.
public struct OverviewView: View {
    @ObservedObject public var model: ShelfModel
    
    public init(model: ShelfModel) {
        self.model = model
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: TUCKED + Settings Gear
            HStack {
                Text("TUCKED")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .tracking(1.2)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let status = model.quitStatusMessage {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                }
                
                Button(action: {
                    model.navigateToSettings()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
                .accessibilityLabel("Open Settings")
            }
            .padding(.bottom, 2)
            
            // Section 1: CPU & MEMORY side by side
            HStack(alignment: .top, spacing: 24) {
                // CPU Column
                VStack(alignment: .leading, spacing: 8) {
                    Text("CPU")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(TuckedFormatter.formatPercent(model.systemSnapshot.cpu.totalUsage))
                            .font(.system(size: 26, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                        
                        HealthPill(
                            text: model.systemSnapshot.cpu.status.rawValue,
                            color: statusColor(for: model.systemSnapshot.cpu.status)
                        )
                        Spacer()
                    }
                    
                    SparklineView(data: model.cpuHistory, color: .blue)
                    
                    VStack(spacing: 4) {
                        MetricStatRow(label: "User", value: TuckedFormatter.formatPercent(model.systemSnapshot.cpu.userUsage))
                        MetricStatRow(label: "System", value: TuckedFormatter.formatPercent(model.systemSnapshot.cpu.systemUsage))
                        MetricStatRow(label: "Idle", value: TuckedFormatter.formatPercent(model.systemSnapshot.cpu.idleUsage))
                        MetricStatRow(label: "Temp", value: formattedTemp)
                        MetricStatRow(label: fanLabel, value: formattedFan)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Memory Column
                VStack(alignment: .leading, spacing: 8) {
                    Text("MEMORY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(TuckedFormatter.formatPercent(model.systemSnapshot.memory.usedPercentage))
                            .font(.system(size: 26, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                        
                        HealthPill(
                            text: model.systemSnapshot.memory.status.rawValue,
                            color: statusColor(for: model.systemSnapshot.memory.status)
                        )
                        Spacer()
                    }
                    
                    SparklineView(data: model.memoryHistory, color: .purple)
                    
                    VStack(spacing: 4) {
                        MetricStatRow(label: "Used", value: TuckedFormatter.formatBytes(model.systemSnapshot.memory.usedBytes))
                        MetricStatRow(label: "Free", value: TuckedFormatter.formatBytes(model.systemSnapshot.memory.freeBytes))
                        MetricStatRow(label: "Swap", value: TuckedFormatter.formatBytes(model.systemSnapshot.memory.swapBytes))
                        MetricStatRow(label: "Compressed", value: TuckedFormatter.formatBytes(model.systemSnapshot.memory.compressedBytes))
                        
                        // Vertical spacing placeholder to balance against CPU Temp & Fan rows
                        Color.clear.frame(height: 16)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            Divider()
            
            // Section 2: NETWORK
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("NETWORK")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    HealthPill(
                        text: model.systemSnapshot.network.status.rawValue,
                        color: networkStatusColor(for: model.systemSnapshot.network.status)
                    )
                }
                
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Text("↓")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        Text(TuckedFormatter.formatPanelRate(model.systemSnapshot.network.rxBytesPerSecond))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 135, alignment: .leading)
                    
                    HStack(spacing: 4) {
                        Text("↑")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        Text(TuckedFormatter.formatPanelRate(model.systemSnapshot.network.txBytesPerSecond))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 135, alignment: .leading)
                    
                    Spacer()
                }
                
                SparklineView(data: model.networkRxHistory, maxScale: nil, color: .teal)
                
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        MetricStatRow(label: "Latency", value: formattedLatency)
                        MetricStatRow(label: "Signal", value: formattedSignal)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(spacing: 4) {
                        MetricStatRow(label: "Jitter", value: formattedJitter)
                        MetricStatRow(label: "Link", value: formattedLink)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            Divider()
            
            // Section 3: HEAVY RIGHT NOW (Two Permanent Columns: Top CPU & Top Memory)
            VStack(alignment: .leading, spacing: 8) {
                Text("HEAVY RIGHT NOW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(alignment: .top, spacing: 24) {
                    // Top CPU Column
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOP CPU")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.bottom, 2)
                        
                        if model.diagnosticSnapshot.isMeasuringCPUProcesses {
                            Text("Measuring…")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(height: 120, alignment: .topLeading)
                        } else if model.diagnosticSnapshot.topCPUProcesses.isEmpty {
                            Text("No heavy CPU processes")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(height: 120, alignment: .topLeading)
                        } else {
                            ForEach(model.diagnosticSnapshot.topCPUProcesses) { item in
                                ProcessRowView(
                                    item: item,
                                    formattedMetric: "\(Int(round(item.cpuUsagePercent)))%",
                                    onQuit: { p in model.requestQuit(for: p) }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    
                    // Top Memory Column
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOP MEMORY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.bottom, 2)
                        
                        if model.diagnosticSnapshot.topMemoryProcesses.isEmpty {
                            Text("Loading…")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(height: 120, alignment: .topLeading)
                        } else {
                            ForEach(model.diagnosticSnapshot.topMemoryProcesses) { item in
                                ProcessRowView(
                                    item: item,
                                    formattedMetric: TuckedFormatter.formatBytes(item.memoryBytes),
                                    onQuit: { p in model.requestQuit(for: p) }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .padding(18)
        .frame(width: 550)
    }
    
    // MARK: - Computed Formatters
    
    private var formattedTemp: String {
        if let celsius = model.diagnosticSnapshot.thermal.cpuTemperatureCelsius {
            return "\(celsius)°C"
        }
        return model.diagnosticSnapshot.thermal.state == .unavailable ? "-" : "Measuring…"
    }
    
    private var fanLabel: String {
        return model.diagnosticSnapshot.thermal.fans.count > 1 ? "Fans" : "Fan"
    }
    
    private var formattedFan: String {
        let thermal = model.diagnosticSnapshot.thermal
        if thermal.state == .fanless {
            return "Fanless"
        }
        if !thermal.fans.isEmpty {
            return TuckedFormatter.formatFanRPM(isFanless: false, rpms: thermal.fans.map { $0.rpm })
        }
        return thermal.state == .unavailable ? "-" : "Measuring…"
    }
    
    private var formattedLatency: String {
        if let ms = model.diagnosticSnapshot.networkDiagnostics.latencyMs {
            return "\(Int(round(ms))) ms"
        }
        return model.diagnosticSnapshot.networkDiagnostics.isMeasuring ? "Measuring…" : "-"
    }
    
    private var formattedJitter: String {
        if let ms = model.diagnosticSnapshot.networkDiagnostics.jitterMs {
            return "\(Int(round(ms))) ms"
        }
        return model.diagnosticSnapshot.networkDiagnostics.isMeasuring ? "Measuring…" : "-"
    }
    
    private var formattedSignal: String {
        if let rssi = model.diagnosticSnapshot.networkDiagnostics.wifiRSSI {
            return "\(rssi) dBm"
        }
        return "-"
    }
    
    private var formattedLink: String {
        if let mbps = model.diagnosticSnapshot.networkDiagnostics.wifiLinkRateMbps {
            if mbps >= 1000 {
                return String(format: "%.1f Gbps", mbps / 1000.0)
            } else {
                return "\(Int(round(mbps))) Mbps"
            }
        }
        return "-"
    }
    
    private func statusColor(for status: CPUHealthStatus) -> Color {
        switch status {
        case .normal: return .green
        case .heavy: return .orange
        case .critical: return .red
        }
    }
    
    private func statusColor(for status: MemoryHealthStatus) -> Color {
        switch status {
        case .normal: return .green
        case .heavy: return .orange
        case .critical: return .red
        }
    }
    
    private func networkStatusColor(for status: NetworkHealthStatus) -> Color {
        switch status {
        case .stable: return .green
        case .degraded: return .orange
        case .poor: return .red
        case .checking, .offline: return .secondary
        }
    }
}
