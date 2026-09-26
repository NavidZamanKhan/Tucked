import Foundation
import AppKit

/// Central coordinator retaining the application subsystems and lifecycle observers.
@MainActor
public final class AppCoordinator {
    public static let shared = AppCoordinator()
    
    public let monitoringCoordinator: MonitoringCoordinator
    public let shelfModel: ShelfModel
    public let shelfController: ShelfController
    public let statusItemController: StatusItemController
    
    private var sleepObserver: Any?
    private var wakeObserver: Any?
    
    private init() {
        let coordinator = MonitoringCoordinator()
        let model = ShelfModel()
        let shelf = ShelfController(model: model, coordinator: coordinator)
        let status = StatusItemController(shelfController: shelf)
        
        self.monitoringCoordinator = coordinator
        self.shelfModel = model
        self.shelfController = shelf
        self.statusItemController = status
        
        setupSnapshotBindings()
        setupWorkspaceNotifications()
    }
    
    public func start() {
        TuckedLog.app.info("Tucked starting in Passive Mode")
        monitoringCoordinator.start()
    }
    
    public func stop() {
        TuckedLog.app.info("Tucked shutting down")
        monitoringCoordinator.stop()
        if let obs = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        if let obs = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }
    
    private func setupSnapshotBindings() {
        monitoringCoordinator.onSystemSnapshot = { [weak self] snapshot in
            guard let self = self else { return }
            Task { @MainActor in
                self.statusItemController.update(with: snapshot)
                self.shelfModel.updateSystemSnapshot(snapshot, history: self.monitoringCoordinator.historyStore)
            }
        }
        
        monitoringCoordinator.onDiagnosticSnapshot = { [weak self] diagnostic in
            guard let self = self else { return }
            Task { @MainActor in
                self.shelfModel.updateDiagnosticSnapshot(diagnostic)
            }
        }
    }
    
    private func setupWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        
        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.monitoringCoordinator.handleSystemSleep()
        }
        
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.monitoringCoordinator.handleSystemWake()
        }
    }
}
