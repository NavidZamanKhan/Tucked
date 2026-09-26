import Foundation
import AppKit

/// Application delegate managing native lifecycle.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce accessory activation policy so Tucked lives purely in the menu bar
        NSApp.setActivationPolicy(.accessory)
        AppCoordinator.shared.start()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        AppCoordinator.shared.stop()
    }
}
