import SwiftUI

/// Canonical overview monitoring surface for Tucked.
public struct OverviewView: View {
    @ObservedObject public var model: ShelfModel
    
    private let skeletonCPUWidths: [CGFloat] = [85, 110, 70, 95, 60, 80]
    private let skeletonMemoryWidths: [CGFloat] = [100, 75, 90, 65, 115, 80]
    
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
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(4)
                }
                
                Button(action: {
                    model.navigateToSettings()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
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
                    
                    HStack(alignment: .center, spacing: 8) {
                        Text(TuckedFormatter.formatPercent(model.systemSnapshot.cpu.totalUsage))
                            .font(.system(size: 26, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                        
                        HealthStatusIndicator.cpu(status: model.systemSnapshot.cpu.status)
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
                    
                    HStack(alignment: .center, spacing: 8) {
                        Text(TuckedFormatter.formatPercent(model.systemSnapshot.memory.usedPercentage))
                            .font(.system(size: 26, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                        
                        HealthStatusIndicator.memory(status: model.systemSnapshot.memory.status)
                        Spacer()
                    }
                    
                    SparklineView(data: model.memoryHistory, color: .purple)
                    
                    VStack(spacing: 4) {
                        MetricStatRow(label: "App", value: TuckedFormatter.formatBytes(model.systemSnapshot.memory.appBytes))
                        MetricStatRow(label: "Wired", value: TuckedFormatter.formatBytes(model.systemSnapshot.memory.wiredBytes))
                        MetricStatRow(label: "Compressed", value: TuckedFormatter.formatBytes(model.systemSnapshot.memory.compressedBytes))
                        MetricStatRow(label: "Free", value: TuckedFormatter.formatBytes(model.systemSnapshot.memory.freeBytes))
                        MetricStatRow(label: "Swap", value: TuckedFormatter.formatBytes(model.systemSnapshot.memory.swapBytes))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            Divider()
            
            // Section 2: NETWORK
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("NETWORK")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    HealthStatusIndicator.network(status: model.systemSnapshot.network.status)
                }
                
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Text("↓")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.pink)
                        Text(TuckedFormatter.formatPanelRate(model.systemSnapshot.network.rxBytesPerSecond))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 135, alignment: .leading)
                    
                    HStack(spacing: 4) {
                        Text("↑")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.teal)
                        Text(TuckedFormatter.formatPanelRate(model.systemSnapshot.network.txBytesPerSecond))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 135, alignment: .leading)
                    
                    Spacer()
                }
                
                BidirectionalNetworkSparklineView(
                    uploadData: model.networkTxHistory,
                    downloadData: model.networkRxHistory,
                    uploadColor: .teal,
                    downloadColor: .pink
                )
                
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        HStack {
                            Text("Internet")
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(model.diagnosticSnapshot.networkDiagnostics.isInternetUp ? Color.green : Color.red)
                                    .frame(width: 7, height: 7)
                                Text(model.diagnosticSnapshot.networkDiagnostics.isInternetUp ? "Connected" : "Disconnected")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        MetricStatRow(label: "Local IP", value: model.diagnosticSnapshot.networkDiagnostics.localIP ?? "-")
                        MetricStatRow(label: "Public IP", value: model.diagnosticSnapshot.networkDiagnostics.publicIP ?? (model.diagnosticSnapshot.networkDiagnostics.isMeasuring ? "Loading…" : "-"))
                        MetricStatRow(label: "Total In", value: TuckedFormatter.formatBytes(model.systemSnapshot.network.totalRxBytes))
                        HStack {
                            Text("Total Out")
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: 6) {
                                Text(TuckedFormatter.formatBytes(model.systemSnapshot.network.totalTxBytes))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary)
                                Button(action: {
                                    model.resetNetworkTotals()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Reset network totals")
                                .accessibilityLabel("Reset network totals")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(spacing: 4) {
                        MetricStatRow(label: "Latency", value: formattedLatency)
                        MetricStatRow(label: "Jitter", value: formattedJitter)
                        MetricStatRow(label: "Signal", value: formattedSignal)
                        MetricStatRow(label: "Link", value: formattedLink)
                        MetricStatRow(label: "Interface", value: formattedInterface)
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
                        
                        if model.diagnosticSnapshot.isMeasuringCPUProcesses && model.diagnosticSnapshot.topCPUProcesses.isEmpty {
                            ForEach(0..<6, id: \.self) { index in
                                ProcessSkeletonRowView(nameWidth: skeletonCPUWidths[index], metricWidth: 32)
                            }
                        } else if model.diagnosticSnapshot.topCPUProcesses.isEmpty {
                            Text("No heavy CPU processes")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(height: 140, alignment: .topLeading)
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
                        
                        if model.diagnosticSnapshot.isMeasuringCPUProcesses && model.diagnosticSnapshot.topMemoryProcesses.isEmpty {
                            ForEach(0..<6, id: \.self) { index in
                                ProcessSkeletonRowView(nameWidth: skeletonMemoryWidths[index], metricWidth: 42)
                            }
                        } else if model.diagnosticSnapshot.topMemoryProcesses.isEmpty {
                            Text("No heavy memory processes")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(height: 140, alignment: .topLeading)
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
                .animation(.easeInOut(duration: 0.22), value: model.diagnosticSnapshot.topCPUProcesses.isEmpty)
                .animation(.easeInOut(duration: 0.22), value: model.diagnosticSnapshot.isMeasuringCPUProcesses)
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
    
    private var formattedInterface: String {
        if let name = model.diagnosticSnapshot.networkDiagnostics.interfaceName {
            return model.diagnosticSnapshot.networkDiagnostics.wifiRSSI != nil ? "Wi-Fi (\(name))" : name
        }
        return model.diagnosticSnapshot.networkDiagnostics.localIP != nil ? "en0" : "-"
    }
    

}
