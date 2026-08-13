import Foundation

/// Minimal local install metadata used only for onboarding and migration decisions.
/// No identifier is generated, and no value is transmitted off-device.
final class InstallStateStore {
    nonisolated static let shared = InstallStateStore()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let firstOpenAt = "SpeachTextFirstOpenAt"
        static let legacyFirstOpenAt = "AnalyticsFirstOpenAt"
        static let legacyAnonymousInstallID = "AnalyticsAnonymousInstallID"
        static let legacyAnalyticsConsent = "ShareAnonymousAnalytics"
    }

    private init() {}

    /// Returns true only for a genuinely new installation. Existing upstream-app users are
    /// migrated from the old local timestamp without being treated as new installs.
    @discardableResult
    nonisolated func ensureFirstOpenRecorded() -> Bool {
        if self.defaults.object(forKey: Keys.firstOpenAt) != nil {
            self.purgeLegacyAnalyticsIdentifier()
            return false
        }

        if let legacyTimestamp = self.defaults.object(forKey: Keys.legacyFirstOpenAt) as? Double,
           legacyTimestamp > 0
        {
            self.defaults.set(legacyTimestamp, forKey: Keys.firstOpenAt)
            self.defaults.removeObject(forKey: Keys.legacyFirstOpenAt)
            self.purgeLegacyAnalyticsIdentifier()
            return false
        }

        self.defaults.set(Date().timeIntervalSince1970, forKey: Keys.firstOpenAt)
        self.purgeLegacyAnalyticsIdentifier()
        return true
    }

    nonisolated var firstOpenAt: Date? {
        let timestamp = self.defaults.double(forKey: Keys.firstOpenAt)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private nonisolated func purgeLegacyAnalyticsIdentifier() {
        self.defaults.removeObject(forKey: Keys.legacyAnonymousInstallID)
        self.defaults.removeObject(forKey: Keys.legacyAnalyticsConsent)
    }
}
