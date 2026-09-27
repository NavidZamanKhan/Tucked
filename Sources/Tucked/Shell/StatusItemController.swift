import Foundation
import AppKit

/// Controls the single continuous menu bar NSStatusItem.
@MainActor
public final class StatusItemController: NSObject {
    public let statusItem: NSStatusItem
    private weak var shelfController: ShelfController?
    private let contextMenu = NSMenu()
    
    public init(shelfController: ShelfController) {
        // Fixed length provides a stable buffer zone on both sides so number fluctuations do not move the app
        self.statusItem = NSStatusBar.system.statusItem(withLength: 195)
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
        
        let (downVal, downUnit) = TuckedFormatter.menuBarRateComponents(rxRate)
        let (upVal, upUnit) = TuckedFormatter.menuBarRateComponents(txRate)
        
        let labelFont = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        let separatorFont = NSFont.systemFont(ofSize: 10, weight: .regular)
        let arrowFont = NSFont.systemFont(ofSize: 9.5, weight: .bold)
        let unitFont = NSFont.systemFont(ofSize: 8.5, weight: .semibold)
        
        let primaryColor = NSColor.labelColor
        let secondaryColor = NSColor.secondaryLabelColor
        let separatorColor = NSColor.tertiaryLabelColor
        
        let attributed = NSMutableAttributedString()
        
        func append(_ text: String, font: NSFont, color: NSColor, baselineOffset: CGFloat = 0) {
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            if baselineOffset != 0 {
                attrs[.baselineOffset] = baselineOffset
            }
            attributed.append(NSAttributedString(string: text, attributes: attrs))
        }
        
        // CPU
        append("CPU ", font: labelFont, color: secondaryColor)
        append("\(cpuPercent)", font: numberFont, color: primaryColor)
        
        // Separator
        append("  ·  ", font: separatorFont, color: separatorColor)
        
        // RAM
        append("RAM ", font: labelFont, color: secondaryColor)
        append("\(ramPercent)", font: numberFont, color: primaryColor)
        
        // Separator
        append("  ·  ", font: separatorFont, color: separatorColor)
        
        // Download: ↓ 13K
        append("↓", font: arrowFont, color: secondaryColor, baselineOffset: 0.5)
        append(downVal, font: numberFont, color: primaryColor)
        append(downUnit, font: unitFont, color: secondaryColor, baselineOffset: 0.8)
        
        append(" ", font: labelFont, color: secondaryColor)
        
        // Upload: ↑ 151K
        append("↑", font: arrowFont, color: secondaryColor, baselineOffset: 0.5)
        append(upVal, font: numberFont, color: primaryColor)
        append(upUnit, font: unitFont, color: secondaryColor, baselineOffset: 0.8)
        
        // Center alignment so content expands symmetrically in the buffer zone
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributed.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attributed.length))
        
        button.attributedTitle = attributed
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
