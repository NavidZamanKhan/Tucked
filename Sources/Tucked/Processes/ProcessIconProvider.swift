import AppKit

/// Fast, in-memory cache for process icons.
/// Resolved on-demand only when the UI renders visible process rows in the expanded shelf.
@MainActor
public final class ProcessIconProvider {
    public static let shared = ProcessIconProvider()
    
    private let cache = NSCache<NSNumber, NSImage>()
    private lazy var defaultIcon: NSImage = {
        NSWorkspace.shared.icon(forFile: "/bin/bash")
    }()
    
    private init() {
        cache.countLimit = 128
    }
    
    /// Resolves an icon for the given process ID.
    public func icon(for pid: Int32) -> NSImage {
        let key = NSNumber(value: pid)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        let resolved: NSImage
        if let app = NSRunningApplication(processIdentifier: pid), let appIcon = app.icon {
            resolved = appIcon
        } else {
            resolved = defaultIcon
        }
        
        cache.setObject(resolved, forKey: key)
        return resolved
    }
    
    /// Clears the icon cache.
    public func clear() {
        cache.removeAllObjects()
    }
}
