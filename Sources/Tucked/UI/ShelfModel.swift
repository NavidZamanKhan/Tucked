import Foundation
import SwiftUI
import Combine

public enum ShelfRoute {
    case overview
    case settings
}

@MainActor
public final class ShelfModel: ObservableObject {
    @Published public var currentRoute: ShelfRoute = .overview
    @Published public var systemSnapshot: SystemSnapshot = SystemSnapshot()
    @Published public var diagnosticSnapshot: DiagnosticSnapshot = DiagnosticSnapshot()
    @Published public var cpuHistory: [Double] = []
    @Published public var memoryHistory: [Double] = []
    @Published public var networkRxHistory: [Double] = []
    @Published public var networkTxHistory: [Double] = []
    
    // Status message for process termination
    @Published public var quitStatusMessage: String?
    
    // Active appearance theme
    @Published public var currentTheme: AppTheme = Preferences.shared.appTheme
    @Published public var isSystemDark: Bool = ShelfModel.checkSystemDark()
    
    public static func checkSystemDark() -> Bool {
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    
    public var isEffectiveDark: Bool {
        switch currentTheme {
        case .system: return isSystemDark
        case .light: return false
        case .dark: return true
        }
    }
    
    public var preferredColorScheme: ColorScheme? {
        switch currentTheme {
        case .system: return isSystemDark ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    public func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        Preferences.shared.appTheme = theme
        isSystemDark = ShelfModel.checkSystemDark()
    }
    
    public init() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSystemDark = ShelfModel.checkSystemDark()
            }
        }
    }
    
    public func updateSystemSnapshot(_ snapshot: SystemSnapshot, history: HistoryStore) {
        self.systemSnapshot = snapshot
        self.cpuHistory = history.cpuHistory()
        self.memoryHistory = history.memoryHistory()
        self.networkRxHistory = history.networkRxHistory()
        self.networkTxHistory = history.networkTxHistory()
    }
    
    public func updateDiagnosticSnapshot(_ snapshot: DiagnosticSnapshot) {
        self.diagnosticSnapshot = snapshot
    }
    
    public func requestQuit(for item: ProcessItem) {
        let success = ProcessTerminationPolicy.terminate(pid: item.pid, expectedName: item.name)
        if success {
            quitStatusMessage = "Terminated \(item.name)"
        } else {
            quitStatusMessage = "Couldn't terminate \(item.name)"
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.quitStatusMessage != nil {
                self.quitStatusMessage = nil
            }
        }
    }
    
    public func navigateToSettings() {
        currentRoute = .settings
    }
    
    public func navigateToOverview() {
        currentRoute = .overview
    }
}
