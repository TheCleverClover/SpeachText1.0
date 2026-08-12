import Foundation

struct PrivacyLockProtectedApplication: Sendable, Hashable, Identifiable {
    let bundleID: String
    let name: String

    var id: String { self.bundleID.lowercased() }
}

struct PrivacyLockDecision: Sendable, Equatable {
    enum Reason: Sendable, Equatable {
        case disabled
        case protectedApplication(String)
        case customApplication(String)
        case sensitiveWindow(String)
        case notProtected
    }

    let isLocked: Bool
    let reason: Reason

    static let unlocked = PrivacyLockDecision(isLocked: false, reason: .notProtected)
}

enum PrivacyLockPolicy {
    static let builtInProtectedApplications: [PrivacyLockProtectedApplication] = [
        PrivacyLockProtectedApplication(bundleID: "com.1password.1password", name: "1Password"),
        PrivacyLockProtectedApplication(bundleID: "com.agilebits.onepassword7", name: "1Password 7"),
        PrivacyLockProtectedApplication(bundleID: "com.bitwarden.desktop", name: "Bitwarden"),
        PrivacyLockProtectedApplication(bundleID: "com.apple.passwords", name: "Passwords"),
        PrivacyLockProtectedApplication(bundleID: "com.apple.keychainaccess", name: "Keychain Access"),
        PrivacyLockProtectedApplication(bundleID: "com.apple.keychainaccess.keychainaccess", name: "Keychain Access"),
        PrivacyLockProtectedApplication(bundleID: "com.dashlane.dashlanephonefinal", name: "Dashlane"),
        PrivacyLockProtectedApplication(bundleID: "com.enpass.Enpass-Desktop", name: "Enpass"),
        PrivacyLockProtectedApplication(bundleID: "com.keepersecurity.keeperpasswordmanager", name: "Keeper"),
        PrivacyLockProtectedApplication(bundleID: "com.lastpass.LastPass", name: "LastPass"),
        PrivacyLockProtectedApplication(bundleID: "com.keepassxc.keepassxc", name: "KeePassXC"),
        PrivacyLockProtectedApplication(bundleID: "me.proton.Pass", name: "Proton Pass"),
    ]

    private static let sensitiveApplicationNameKeywords = [
        "password", "keychain", "1password", "bitwarden", "keepass", "lastpass",
        "dashlane", "proton pass", "banking", "bank ", "wallet", "payment",
    ]

    private static let sensitiveWindowKeywords = [
        "private browsing", "private window", "incognito", "inprivate",
        "password", "passkey", "one-time passcode", "verification code",
        "online banking", "banking", "checkout", "payment details",
    ]

    static func evaluate(
        appName: String,
        bundleID: String,
        windowTitle: String,
        enabled: Bool,
        customBundleIDs: [String],
        protectSensitiveWindows: Bool
    ) -> PrivacyLockDecision {
        guard enabled else {
            return PrivacyLockDecision(isLocked: false, reason: .disabled)
        }

        let normalizedBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedAppName = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedWindowTitle = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        for application in self.builtInProtectedApplications {
            let protectedID = application.bundleID.lowercased()
            if normalizedBundleID == protectedID || normalizedBundleID.hasPrefix(protectedID + ".") {
                return PrivacyLockDecision(
                    isLocked: true,
                    reason: .protectedApplication(application.name)
                )
            }
        }

        let normalizedCustomBundleIDs = customBundleIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if let match = normalizedCustomBundleIDs.first(where: {
            normalizedBundleID == $0 || normalizedBundleID.hasPrefix($0 + ".")
        }) {
            return PrivacyLockDecision(isLocked: true, reason: .customApplication(match))
        }

        if self.sensitiveApplicationNameKeywords.contains(where: { normalizedAppName.contains($0) }) {
            return PrivacyLockDecision(
                isLocked: true,
                reason: .protectedApplication(appName.isEmpty ? "Sensitive application" : appName)
            )
        }

        if protectSensitiveWindows,
           let keyword = self.sensitiveWindowKeywords.first(where: { normalizedWindowTitle.contains($0) })
        {
            return PrivacyLockDecision(isLocked: true, reason: .sensitiveWindow(keyword))
        }

        return .unlocked
    }

    static func currentDecision(
        appName: String,
        bundleID: String,
        windowTitle: String,
        settings: SettingsStore = .shared
    ) -> PrivacyLockDecision {
        self.evaluate(
            appName: appName,
            bundleID: bundleID,
            windowTitle: windowTitle,
            enabled: settings.privacyLockEnabled,
            customBundleIDs: settings.privacyLockCustomBundleIDs,
            protectSensitiveWindows: settings.privacyLockProtectSensitiveWindows
        )
    }

    static func reasonText(for decision: PrivacyLockDecision) -> String {
        switch decision.reason {
        case .disabled, .notProtected:
            return ""
        case .protectedApplication(let name):
            return "Protected application: \(name)"
        case .customApplication(let bundleID):
            return "User-protected application: \(bundleID)"
        case .sensitiveWindow(let keyword):
            return "Sensitive window detected: \(keyword)"
        }
    }
}
