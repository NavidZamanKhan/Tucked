import Foundation
import ServiceManagement

/// Handles Launch at Login registration using ServiceManagement.SMAppService.mainApp.
public final class LoginItemService: @unchecked Sendable {
    public static let shared = LoginItemService()
    
    private init() {}
    
    public var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    public var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Not Registered"
        case .requiresApproval:
            return "Requires System Approval"
        case .notFound:
            return "Not Found"
        @unknown default:
            return "Unknown"
        }
    }
    
    public func setEnabled(_ enable: Bool) throws {
        if enable {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
