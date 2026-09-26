import Foundation
import AppKit

/// Controls the single continuous menu bar NSStatusItem.
@MainActor
public final class StatusItemController: NSObject {
    public let statusItem: NSStatusItem
    private weak var shelfController: ShelfController?
    private let contextMenu = NSMenu()
    
    public init(shelfController: ShelfController) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.shelfController = shelfController
        super.init()
        
        setupButton()
        setupContextMenu()
    }
    
    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleButtonClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateTitle(cpuPercent: 0, ramPercent: 0, rxRate: 0, txRate: 0)
    }
    
    private func setupContextMenu() {
        contextMenu.addItem(NSMenuItem(title: "Open Tucked", action: #selector(menuOpenTucked), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem(title: "Settings…", action: #selector(menuOpenSettings), keyEquivalent: ","))
        contextMenu.addItem(NSMenuItem.separator())
        
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.state = Preferences.shared.launchAtLogin ? .on : .off
        contextMenu.addItem(loginItem)
        
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit Tucked", action: #selector(menuQuit), keyEquivalent: "q"))
        
        for item in contextMenu.items {
            item.target = self
        }
    }
    
    public func update(with snapshot: SystemSnapshot) {
        let cpu = Int(round(snapshot.cpu.totalUsage))
        let ram = Int(round(snapshot.memory.usedPercentage))
        updateTitle(
            cpuPercent: cpu,
            ramPercent: ram,
            rxRate: snapshot.network.rxBytesPerSecond,
            txRate: snapshot.network.txBytesPerSecond
        )
    }
    
    public func updateTitle(cpuPercent: Int, ramPercent: Int, rxRate: Double, txRate: Double) {
        guard let button = statusItem.button else { return }
        
        let downStr = TuckedFormatter.formatMenuBarRate(rxRate)
        let upStr = TuckedFormatter.formatMenuBarRate(txRate)
        let titleString = "CPU \(cpuPercent) · RAM \(ramPercent) · ↓\(downStr) ↑\(upStr)"
        
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        
        button.attributedTitle = NSAttributedString(string: titleString, attributes: attributes)
        button.toolTip = "Tucked: CPU \(cpuPercent)%, RAM \(ramPercent)%, Download \(downStr)/s, Upload \(upStr)/s"
    }
    
    @objc private func handleButtonClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control)) {
            // Update Launch at Login checkmark before showing menu
            if let loginItem = contextMenu.items.first(where: { $0.action == #selector(toggleLaunchAtLogin(_:)) }) {
                loginItem.state = Preferences.shared.launchAtLogin ? .on : .off
            }
            statusItem.menu = contextMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            shelfController?.toggle(relativeTo: sender)
        }
    }
    
    @objc private func menuOpenTucked() {
        guard let button = statusItem.button else { return }
        shelfController?.show(relativeTo: button)
    }
    
    @objc private func menuOpenSettings() {
        guard let button = statusItem.button else { return }
        shelfController?.model.navigateToSettings()
        shelfController?.show(relativeTo: button)
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = !Preferences.shared.launchAtLogin
        Preferences.shared.launchAtLogin = newState
        sender.state = newState ? .on : .off
        try? LoginItemService.shared.setEnabled(newState)
    }
    
    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
