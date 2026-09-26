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
    
    /// Requests normal termination for a validated process.
    public static func requestNormalQuit(pid: Int32, expectedName: String) -> Bool {
        guard pid > 1 else { return false }
        guard pid != ProcessInfo.processInfo.processIdentifier else { return false }
        
        // Step 1: Check if it is a GUI application
        if let app = NSRunningApplication(processIdentifier: pid) {
            // Verify application identity
            if let localizedName = app.localizedName, !localizedName.isEmpty {
                TuckedLog.termination.info("Requesting GUI normal terminate for \(localizedName) [PID \(pid)]")
            }
            return app.terminate()
        }
        
        // Step 2: Same-user CLI process -> SIGTERM only
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
        
        TuckedLog.termination.info("Sending SIGTERM to CLI process \(pbiName) [PID \(pid)]")
        let killResult = kill(pid, SIGTERM)
        return killResult == 0
    }
}
