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
    
    public init() {}
    
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
