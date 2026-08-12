import AppKit
import Foundation

@MainActor
enum RecoveryVaultActions {
    static func undo(_ record: RecoveryVaultRecord) async -> Bool {
        guard let targetPID = self.targetPID(for: record) else { return false }
        _ = TypingService.activateApp(pid: targetPID)
        try? await Task.sleep(nanoseconds: 180_000_000)
        let succeeded = TypingService().undoLastChange(preferredTargetPID: targetPID)
        if succeeded {
            RecoveryVaultStore.shared.markUndone(record.id)
        }
        return succeeded
    }

    static func restore(_ record: RecoveryVaultRecord) async -> Bool {
        guard let targetPID = self.targetPID(for: record) else { return false }
        _ = TypingService.activateApp(pid: targetPID)
        try? await Task.sleep(nanoseconds: 220_000_000)
        TypingService().typeTextInstantly(record.text, preferredTargetPID: targetPID)
        RecoveryVaultStore.shared.markRestored(record.id)
        return true
    }

    static func targetPID(for record: RecoveryVaultRecord) -> pid_t? {
        if let storedPID = record.targetPID {
            let candidate = pid_t(storedPID)
            if let app = NSRunningApplication(processIdentifier: candidate),
               record.bundleID.isEmpty || app.bundleIdentifier == record.bundleID
            {
                return candidate
            }
        }

        guard !record.bundleID.isEmpty else { return nil }
        return NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == record.bundleID && !$0.isTerminated
        })?.processIdentifier
    }
}
