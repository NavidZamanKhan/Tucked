import Foundation

/// Minimal preferences storage for Tucked.
public final class Preferences: @unchecked Sendable {
    public static let shared = Preferences()
    
    private let defaults: UserDefaults
    private let launchAtLoginKey = "tucked.launchAtLogin"
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: launchAtLoginKey) }
        set { defaults.set(newValue, forKey: launchAtLoginKey) }
    }
}
