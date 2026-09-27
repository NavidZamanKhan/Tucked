import Foundation

/// Supported visual appearance themes for Tucked.
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Minimal preferences storage for Tucked.
public final class Preferences: @unchecked Sendable {
    public static let shared = Preferences()
    
    private let defaults: UserDefaults
    private let launchAtLoginKey = "tucked.launchAtLogin"
    private let appThemeKey = "tucked.appTheme"
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: launchAtLoginKey) }
        set { defaults.set(newValue, forKey: launchAtLoginKey) }
    }
    
    public var appTheme: AppTheme {
        get {
            guard let raw = defaults.string(forKey: appThemeKey),
                  let theme = AppTheme(rawValue: raw) else {
                return .system
            }
            return theme
        }
        set {
            defaults.set(newValue.rawValue, forKey: appThemeKey)
        }
    }
}
