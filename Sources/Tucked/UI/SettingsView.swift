import SwiftUI

/// In-shelf settings view for Tucked.
public struct SettingsView: View {
    @ObservedObject public var model: ShelfModel
    @State private var launchAtLogin: Bool = Preferences.shared.launchAtLogin
    @State private var loginItemStatus: String = LoginItemService.shared.statusDescription
    
    public init(model: ShelfModel) {
        self.model = model
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header with Back button
            HStack {
                Button(action: {
                    model.navigateToOverview()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Overview")
                
                Spacer()
                
                Text("SETTINGS")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Balance spacing
                Color.clear.frame(width: 44, height: 16)
            }
            
            Divider()
            
            // General Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("GENERAL")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .font(.system(size: 13))
                    .onChange(of: launchAtLogin) { _, newValue in
                        Preferences.shared.launchAtLogin = newValue
                        do {
                            try LoginItemService.shared.setEnabled(newValue)
                            loginItemStatus = LoginItemService.shared.statusDescription
                        } catch {
                            TuckedLog.app.error("Failed to update Launch at Login: \(error.localizedDescription)")
                        }
                    }
                
                Text("Status: \(loginItemStatus)")
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
            }
            
            Divider()
            
            // About Section
            VStack(alignment: .leading, spacing: 6) {
                Text("ABOUT TUCKED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Your Mac, at a glance.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("CPU, memory, network. Nothing you don't need.")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                
                Text("Version 1.0 (Native Apple Silicon)")
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(18)
        .frame(width: 550, height: 350)
    }
}
