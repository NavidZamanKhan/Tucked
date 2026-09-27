import Foundation
import AppKit
import SwiftUI
import Combine

/// Borderless non-activating floating panel hosting the Dynamic Island shelf.
@MainActor
public final class DynamicIslandPanel: NSPanel {
    public var onEscapeKey: (@MainActor () -> Void)?
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    public override func cancelOperation(_ sender: Any?) {
        onEscapeKey?()
    }
}

/// Controls the Dynamic Island floating panel presenting the single Tucked shelf surface.
@MainActor
public final class ShelfController: NSObject {
    public let panel: DynamicIslandPanel
    public let model: ShelfModel
    private weak var coordinator: MonitoringCoordinator?
    private weak var statusItemButton: NSView?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var isAnimating: Bool = false
    private var isDismissing: Bool = false
    
    public init(model: ShelfModel, coordinator: MonitoringCoordinator) {
        let initialRect = NSRect(x: 0, y: 0, width: 610, height: 740)
        self.panel = DynamicIslandPanel(contentRect: initialRect)
        self.model = model
        self.coordinator = coordinator
        super.init()
        
        setupPanel()
    }
    
    private func setupPanel() {
        let contentView = ShelfView(model: model)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 610, height: 740)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        
        panel.onEscapeKey = { [weak self] in
            self?.close()
        }
        
        model.onCloseRequested = { [weak self] in
            Task { @MainActor [weak self] in
                self?.close()
            }
        }
        
        updateAppearance(theme: model.currentTheme)
        
        model.$currentTheme
            .sink { [weak self] theme in
                self?.updateAppearance(theme: theme)
            }
            .store(in: &cancellables)
            
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.model.isSystemDark = ShelfModel.checkSystemDark()
                self.updateAppearance(theme: self.model.currentTheme)
            }
        }
    }
    
    public func updateAppearance(theme: AppTheme) {
        let appearanceName: NSAppearance.Name
        switch theme {
        case .system:
            appearanceName = ShelfModel.checkSystemDark() ? .darkAqua : .aqua
        case .light:
            appearanceName = .aqua
        case .dark:
            appearanceName = .darkAqua
        }
        panel.appearance = NSAppearance(named: appearanceName)
    }
    
    /// Backwards compatibility alias
    public func updatePopoverAppearance(theme: AppTheme) {
        updateAppearance(theme: theme)
    }
    
    public var isVisible: Bool {
        return panel.isVisible && (model.isShelfPresented || isAnimating)
    }
    
    public func toggle(relativeTo positioningView: NSView) {
        if isVisible {
            close()
        } else {
            show(relativeTo: positioningView)
        }
    }
    
    public func show(relativeTo positioningView: NSView) {
        guard !isVisible, !isAnimating else { return }
        
        self.statusItemButton = positioningView
        
        // Ensure starting on Overview route and refresh appearance
        model.navigateToOverview()
        model.isSystemDark = ShelfModel.checkSystemDark()
        updateAppearance(theme: model.currentTheme)
        
        // Position panel frame dynamically relative to the status item
        updatePanelPosition(relativeTo: positioningView)
        
        // Ensure initial collapsed state before showing window
        model.isShelfPresented = false
        
        panel.orderFrontRegardless()
        panel.makeKey()
        
        isAnimating = true
        coordinator?.shelfDidOpen()
        installEventMonitors()
        
        // Gliding spring opening physics at 120Hz
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                self.model.isShelfPresented = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { [weak self] in
                self?.isAnimating = false
            }
        }
    }
    
    public func close() {
        guard isVisible, !isDismissing else { return }
        
        isDismissing = true
        removeEventMonitors()
        
        // Snappy spring collapse
        withAnimation(.spring(response: 0.22, dampingFraction: 0.90)) {
            self.model.isShelfPresented = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self = self else { return }
            self.panel.orderOut(nil)
            self.isDismissing = false
            self.coordinator?.shelfDidClose()
        }
    }
    
    // MARK: - Panel Geometry
    
    private func updatePanelPosition(relativeTo positioningView: NSView) {
        guard let window = positioningView.window,
              let screen = window.screen ?? NSScreen.main else { return }
        
        let buttonRectInWindow = positioningView.convert(positioningView.bounds, to: nil)
        let buttonScreenRect = window.convertToScreen(buttonRectInWindow)
        
        let screenFrame = screen.visibleFrame
        let windowWidth: CGFloat = 610.0 // 550 pill + 30pt padding on each side
        let pillWidth: CGFloat = 550.0
        
        // Center the 550pt pill horizontally under buttonScreenRect.midX
        var windowOriginX = buttonScreenRect.midX - (pillWidth / 2.0) - 30.0
        
        // Clamp window within visible screen bounds
        let minX = screenFrame.minX
        let maxX = screenFrame.maxX - windowWidth
        windowOriginX = min(max(windowOriginX, minX), maxX)
        
        // Calculate anchor fraction relative to the 550pt pill
        let pillOriginX = windowOriginX + 30.0
        let offsetIntoPill = buttonScreenRect.midX - pillOriginX
        let rawFraction = offsetIntoPill / pillWidth
        let clampedFraction = min(max(rawFraction, 0.05), 0.95)
        model.anchorXFraction = clampedFraction
        
        // Vertical placement: top edge of window touches buttonScreenRect.minY
        let windowHeight: CGFloat = min(740.0, screenFrame.height - 10.0)
        let windowOriginY = buttonScreenRect.minY - windowHeight
        
        let targetFrame = NSRect(
            x: windowOriginX,
            y: windowOriginY,
            width: windowWidth,
            height: windowHeight
        )
        
        panel.setFrame(targetFrame, display: false)
    }
    
    // MARK: - Dismissal Handling
    
    private func installEventMonitors() {
        removeEventMonitors()
        
        // Local monitor to handle Escape key and clicks in other local windows
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            
            if event.type == .keyDown && event.keyCode == 53 { // Escape
                Task { @MainActor [weak self] in
                    self?.close()
                }
                return nil
            }
            
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if let eventWindow = event.window, eventWindow !== self.panel {
                    if let button = self.statusItemButton, let window = button.window, eventWindow === window {
                        return event
                    }
                    Task { @MainActor [weak self] in
                        self?.close()
                    }
                }
            }
            
            return event
        }
        
        // Global monitor for clicks outside the application
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isVisible, !self.isDismissing else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            if let button = self.statusItemButton, let window = button.window {
                let buttonScreenRect = window.convertToScreen(button.convert(button.bounds, to: nil))
                if buttonScreenRect.contains(mouseLocation) {
                    return
                }
            }
            
            Task { @MainActor [weak self] in
                self?.close()
            }
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
