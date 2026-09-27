import SwiftUI

/// In-shelf settings view for Tucked featuring system preferences and machine specifications.
public struct SettingsView: View {
    @ObservedObject public var model: ShelfModel
    @State private var launchAtLogin: Bool = Preferences.shared.launchAtLogin
    @State private var loginItemStatus: String = LoginItemService.shared.statusDescription
    
    public init(model: ShelfModel) {
        self.model = model
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Back button
            HStack {
                Button(action: {
                    model.navigateToOverview()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Overview")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Overview")
                
                Spacer()
                
                Text("SETTINGS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Balance spacing against back button
                Color.clear.frame(width: 80, height: 20)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // Section 1: Appearance & General Preferences
            VStack(spacing: 10) {
                // Theme Card
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        Text("System detects macOS mode automatically")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("Theme", selection: Binding(
                        get: { model.currentTheme },
                        set: { newTheme in model.setTheme(newTheme) }
                    )) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 230)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
                )
                
                // Launch at Login Card
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Status: \(loginItemStatus)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, newValue in
                            Preferences.shared.launchAtLogin = newValue
                            do {
                                try LoginItemService.shared.setEnabled(newValue)
                                loginItemStatus = LoginItemService.shared.statusDescription
                            } catch {
                                TuckedLog.app.error("Failed to update Launch at Login: \(error.localizedDescription)")
                            }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
                )
            }
            
            Divider()
            
            // Section 2: Machine Details
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("MACHINE DETAILS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Apple Silicon Native")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(4)
                }
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        SpecTile(label: "Model", value: MachineInfo.current.model)
                        SpecTile(label: "Chip", value: MachineInfo.current.chip)
                        SpecTile(label: "Cores", value: MachineInfo.current.formattedCores)
                    }
                    HStack(spacing: 8) {
                        SpecTile(label: "Memory", value: MachineInfo.current.formattedMemory)
                        SpecTile(label: "OS", value: MachineInfo.current.formattedOS)
                        SpecTile(label: "Uptime", value: MachineInfo.uptimeString)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
                )
            }
            
            Divider()
            
            // Section 3: About Tucked
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tucked")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Your Mac, at a glance. Lightweight native system monitor.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("Version 1.0 (arm64)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(4)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(width: 550)
    }
}

private struct SpecTile: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }
}

