import Foundation
import AppKit
import SwiftUI

/// Controls the NSPopover presenting the single Tucked shelf surface.
@MainActor
public final class ShelfController: NSObject, NSPopoverDelegate {
    public let popover: NSPopover
    public let model: ShelfModel
    private weak var coordinator: MonitoringCoordinator?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    public init(model: ShelfModel, coordinator: MonitoringCoordinator) {
        self.popover = NSPopover()
        self.model = model
        self.coordinator = coordinator
        super.init()
        
        setupPopover()
    }
    
    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.appearance = NSAppearance(named: .aqua)
        
        let contentView = ShelfView(model: model)
        let hostingController = NSHostingController(rootView: contentView)
        popover.contentViewController = hostingController
    }
    
    public var isVisible: Bool {
        return popover.isShown
    }
    
    public func toggle(relativeTo positioningView: NSView) {
        if isVisible {
            close()
        } else {
            show(relativeTo: positioningView)
        }
    }
    
    public func show(relativeTo positioningView: NSView) {
        guard !popover.isShown else { return }
        
        // Ensure starting on Overview route
        model.navigateToOverview()
        
        popover.show(
            relativeTo: positioningView.bounds,
            of: positioningView,
            preferredEdge: .minY
        )
        
        installEventMonitors()
        coordinator?.shelfDidOpen()
    }
    
    public func close() {
        guard popover.isShown else { return }
        popover.performClose(nil)
        removeEventMonitors()
        coordinator?.shelfDidClose()
    }
    
    // MARK: - NSPopoverDelegate
    
    public func popoverDidClose(_ notification: Notification) {
        removeEventMonitors()
        coordinator?.shelfDidClose()
    }
    
    // MARK: - Dismissal Handling
    
    private func installEventMonitors() {
        removeEventMonitors()
        
        // Local monitor to handle Escape key
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == 53 { // Escape
                self.close()
                return nil
            }
            return event
        }
    }
    
    private func removeEventMonitors() {
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
        if let global = globalMonitor {
            NSEvent.removeMonitor(global)
            globalMonitor = nil
        }
    }
}
