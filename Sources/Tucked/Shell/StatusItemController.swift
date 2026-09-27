import Foundation
import AppKit

/// Pixel-perfect view drawing fixed independent metric slots so numbers never push adjacent stats.
final class TuckedStatusView: NSView {
    var cpuPercent: Int = 0 { didSet { needsDisplay = true } }
    var ramPercent: Int = 0 { didSet { needsDisplay = true } }
    var downVal: String = "0" { didSet { needsDisplay = true } }
    var downUnit: String = "K" { didSet { needsDisplay = true } }
    var upVal: String = "0" { didSet { needsDisplay = true } }
    var upUnit: String = "K" { didSet { needsDisplay = true } }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Transparent to all mouse clicks so the underlying NSStatusBarButton receives clicks
        return nil
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let textColor = NSColor.labelColor
        let labelColor = NSColor.labelColor.withAlphaComponent(0.75)
        let separatorColor = NSColor.labelColor.withAlphaComponent(0.35)
        
        let labelFont = NSFont.systemFont(ofSize: 8.5, weight: .regular)
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        let separatorFont = NSFont.systemFont(ofSize: 10, weight: .regular)
        let arrowFont = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        let unitFont = NSFont.systemFont(ofSize: 8.5, weight: .regular)
        
        let yBaseline = floor((bounds.height - 14) / 2) + 1.0
        
        // Slot 1: CPU (fixed at x: 8, buffer width: 48)
        let cpuAttr = NSMutableAttributedString()
        cpuAttr.append(NSAttributedString(string: "CPU ", attributes: [.font: labelFont, .foregroundColor: labelColor, .baselineOffset: 0.8]))
        cpuAttr.append(NSAttributedString(string: "\(cpuPercent)", attributes: [.font: numberFont, .foregroundColor: textColor]))
        cpuAttr.draw(at: NSPoint(x: 8, y: yBaseline))
        
        // Separator 1 (fixed at x: 58)
        let sep1 = NSAttributedString(string: "·", attributes: [.font: separatorFont, .foregroundColor: separatorColor])
        sep1.draw(at: NSPoint(x: 58, y: yBaseline))
        
        // Slot 2: RAM (fixed at x: 68, buffer width: 48)
        let ramAttr = NSMutableAttributedString()
        ramAttr.append(NSAttributedString(string: "RAM ", attributes: [.font: labelFont, .foregroundColor: labelColor, .baselineOffset: 0.8]))
        ramAttr.append(NSAttributedString(string: "\(ramPercent)", attributes: [.font: numberFont, .foregroundColor: textColor]))
        ramAttr.draw(at: NSPoint(x: 68, y: yBaseline))
        
        // Separator 2 (fixed at x: 118)
        let sep2 = NSAttributedString(string: "·", attributes: [.font: separatorFont, .foregroundColor: separatorColor])
        sep2.draw(at: NSPoint(x: 118, y: yBaseline))
        
        // Slot 3: Download (fixed at x: 128, buffer width: 36)
        let downAttr = NSMutableAttributedString()
        downAttr.append(NSAttributedString(string: "↓", attributes: [.font: arrowFont, .foregroundColor: labelColor, .baselineOffset: 0.5, .kern: 1.5]))
        downAttr.append(NSAttributedString(string: downVal, attributes: [.font: numberFont, .foregroundColor: textColor]))
        downAttr.append(NSAttributedString(string: downUnit, attributes: [.font: unitFont, .foregroundColor: labelColor, .baselineOffset: 0.8]))
        downAttr.draw(at: NSPoint(x: 128, y: yBaseline))
        
        // Slot 4: Upload (fixed at x: 166, buffer width: 36)
        let upAttr = NSMutableAttributedString()
        upAttr.append(NSAttributedString(string: "↑", attributes: [.font: arrowFont, .foregroundColor: labelColor, .baselineOffset: 0.5, .kern: 1.5]))
        upAttr.append(NSAttributedString(string: upVal, attributes: [.font: numberFont, .foregroundColor: textColor]))
        upAttr.append(NSAttributedString(string: upUnit, attributes: [.font: unitFont, .foregroundColor: labelColor, .baselineOffset: 0.8]))
        upAttr.draw(at: NSPoint(x: 166, y: yBaseline))
    }
}

/// Controls the single continuous menu bar NSStatusItem.
@MainActor
public final class StatusItemController: NSObject {
    public let statusItem: NSStatusItem
    private let statusView: TuckedStatusView
    private weak var shelfController: ShelfController?
    private let contextMenu = NSMenu()
    
    public init(shelfController: ShelfController) {
        let totalWidth: CGFloat = 205
        // Fixed length provides a stable buffer zone on both sides so number fluctuations do not move the app
        self.statusItem = NSStatusBar.system.statusItem(withLength: totalWidth)
        self.shelfController = shelfController
        self.statusView = TuckedStatusView(frame: NSRect(x: 0, y: 0, width: totalWidth, height: 22))
        super.init()
        
        setupButton()
        setupContextMenu()
    }
    
    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleButtonClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusView.frame = button.bounds
        statusView.autoresizingMask = [.width, .height]
        button.addSubview(statusView)
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
        
        let (downVal, downUnit) = TuckedFormatter.menuBarRateComponents(rxRate)
        let (upVal, upUnit) = TuckedFormatter.menuBarRateComponents(txRate)
        
        statusView.cpuPercent = cpuPercent
        statusView.ramPercent = ramPercent
        statusView.downVal = downVal
        statusView.downUnit = downUnit
        statusView.upVal = upVal
        statusView.upUnit = upUnit
        
        button.toolTip = "Tucked: CPU \(cpuPercent)%, RAM \(ramPercent)%, Download \(downVal)\(downUnit)/s, Upload \(upVal)\(upUnit)/s"
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
