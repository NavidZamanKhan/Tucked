import Foundation
import AppKit
import Darwin

/// Pure policy and execution for normal process termination.
public enum ProcessTerminationPolicy {
    private static let protectedProcessNames: Set<String> = [
        "kernel_task",
        "launchd",
        "WindowServer",
        "loginwindow",
        "Finder",
        "Dock",
        "SystemUIServer",
        "syslogd",
        "distnoted",
        "cfprefsd",
        "coreaudiod",
        "powerd",
        "opendirectoryd",
        "diskarbitrationd"
    ]
    
    /// Determines whether a process is safe and eligible for user normal quit.
    public static func isClosable(pid: Int32, name: String, ownerUID: uid_t) -> Bool {
        // PID 0 (kernel) and PID 1 (launchd) are never closable
        guard pid > 1 else { return false }
        
        // Own process is never closable from this list
        guard pid != ProcessInfo.processInfo.processIdentifier else { return false }
        
        // System and session critical processes are protected
        if protectedProcessNames.contains(name) {
            return false
        }
        
        // Must belong to the current user
        let currentUID = getuid()
        guard ownerUID == currentUID else {
            return false
        }
        
        return true
    }
    
    /// Terminates a validated runaway or user-selected process via SIGKILL.
    @discardableResult
    public static func terminate(pid: Int32, expectedName: String) -> Bool {
        guard pid > 1 else { return false }
        guard pid != ProcessInfo.processInfo.processIdentifier else { return false }
        
        let currentUID = getuid()
        var bsdInfo = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let bytesRead = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, size)
        
        guard bytesRead == size else {
            TuckedLog.termination.error("Process \(pid) exited before signal could be sent")
            return false
        }
        
        // Re-validate UID and protection before sending signal
        guard bsdInfo.pbi_uid == currentUID else {
            TuckedLog.termination.error("Process \(pid) UID mismatch: owned by \(bsdInfo.pbi_uid), expected \(currentUID)")
            return false
        }
        
        let pbiName = withUnsafeBytes(of: bsdInfo.pbi_name) { rawPtr -> String in
            let cStr = rawPtr.baseAddress?.assumingMemoryBound(to: CChar.self)
            return cStr.map { String(cString: $0) } ?? ""
        }
        
        if protectedProcessNames.contains(pbiName) {
            TuckedLog.termination.error("Refusing to terminate protected process: \(pbiName)")
            return false
        }
        
        if let app = NSRunningApplication(processIdentifier: pid) {
            let appName = app.localizedName ?? pbiName
            TuckedLog.termination.info("Terminating GUI application \(appName) [PID \(pid)] via SIGKILL")
            _ = app.forceTerminate()
        } else {
            TuckedLog.termination.info("Terminating CLI process \(pbiName) [PID \(pid)] via SIGKILL")
        }
        
        let killResult = kill(pid, SIGKILL)
        return killResult == 0 || errno == ESRCH
    }
    
    /// Backward-compatible alias for process termination.
    @discardableResult
    public static func requestNormalQuit(pid: Int32, expectedName: String) -> Bool {
        return terminate(pid: pid, expectedName: expectedName)
    }
}
