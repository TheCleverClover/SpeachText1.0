import Combine
import CryptoKit
import Foundation
import Security

struct RecoveryVaultRecord: Codable, Equatable, Identifiable, Sendable {
    enum Source: String, Codable, Sendable {
        case dictation
        case voiceMacro
        case rewrite
        case reprocess
    }

    let id: UUID
    let createdAt: Date
    let text: String
    let appName: String
    let bundleID: String
    let targetPID: Int32?
    let source: Source
    var undoneAt: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        text: String,
        appName: String,
        bundleID: String,
        targetPID: pid_t?,
        source: Source,
        undoneAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.appName = appName
        self.bundleID = bundleID
        self.targetPID = targetPID.map { Int32(truncatingIfNeeded: $0) }
        self.source = source
        self.undoneAt = undoneAt
    }
}

@MainActor
final class RecoveryVaultStore: ObservableObject {
    static let shared = RecoveryVaultStore()

    @Published private(set) var records: [RecoveryVaultRecord] = []

    private let maximumRecordCount = 30
    private let keychainService = "com.speachtext.recovery-vault"
    private let keychainAccount = "vault-key-v1"

    private init() {
        self.load()
    }

    var latestRecoverableRecord: RecoveryVaultRecord? {
        self.records.first(where: { $0.undoneAt == nil })
    }

    func add(
        text: String,
        appName: String,
        bundleID: String,
        targetPID: pid_t?,
        source: RecoveryVaultRecord.Source
    ) {
        guard SettingsStore.shared.recoveryVaultEnabled else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let record = RecoveryVaultRecord(
            text: text,
            appName: appName,
            bundleID: bundleID,
            targetPID: targetPID,
            source: source
        )
        self.records.insert(record, at: 0)
        self.pruneExpiredIfNeeded()
        if self.records.count > self.maximumRecordCount {
            self.records.removeLast(self.records.count - self.maximumRecordCount)
        }
        self.persist()
    }

    func markUndone(_ id: UUID) {
        guard let index = self.records.firstIndex(where: { $0.id == id }) else { return }
        self.records[index].undoneAt = Date()
        self.persist()
    }

    func markRestored(_ id: UUID) {
        guard let index = self.records.firstIndex(where: { $0.id == id }) else { return }
        self.records[index].undoneAt = nil
        self.persist()
    }

    func delete(_ id: UUID) {
        self.records.removeAll { $0.id == id }
        self.persist()
    }

    func clear() {
        self.records.removeAll()
        do {
            try FileManager.default.removeItem(at: self.vaultFileURL)
        } catch where (error as NSError).code == NSFileNoSuchFileError {
            return
        } catch {
            DebugLogger.shared.error("Failed to clear Recovery Vault: \(error.localizedDescription)", source: "RecoveryVault")
        }
    }

    func reload() {
        self.load()
    }

    private func pruneExpiredIfNeeded() {
        let retentionDays = max(1, SettingsStore.shared.recoveryVaultRetentionDays)
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast
        let originalCount = self.records.count
        self.records.removeAll { $0.createdAt < cutoff }
        if self.records.count != originalCount {
            self.persist()
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: self.vaultFileURL.path) else {
            self.records = []
            return
        }
        do {
            let encrypted = try Data(contentsOf: self.vaultFileURL)
            let sealedBox = try AES.GCM.SealedBox(combined: encrypted)
            let decrypted = try AES.GCM.open(sealedBox, using: self.encryptionKey())
            self.records = try JSONDecoder().decode([RecoveryVaultRecord].self, from: decrypted)
                .sorted { $0.createdAt > $1.createdAt }
            self.pruneExpiredIfNeeded()
        } catch {
            self.records = []
            DebugLogger.shared.error("Could not open Recovery Vault: \(error.localizedDescription)", source: "RecoveryVault")
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: self.vaultDirectoryURL,
                withIntermediateDirectories: true
            )
            let plaintext = try JSONEncoder().encode(self.records)
            let sealed = try AES.GCM.seal(plaintext, using: self.encryptionKey())
            guard let combined = sealed.combined else {
                throw RecoveryVaultError.encryptionFailed
            }
            try combined.write(to: self.vaultFileURL, options: [.atomic])
        } catch {
            DebugLogger.shared.error("Failed to save Recovery Vault: \(error.localizedDescription)", source: "RecoveryVault")
        }
    }

    private func encryptionKey() throws -> SymmetricKey {
        var query = self.keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, data.count == 32 {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else {
            throw RecoveryVaultError.keychain(status)
        }

        let keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        var attributes = self.keychainQuery
        attributes[kSecValueData as String] = keyData
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw RecoveryVaultError.keychain(addStatus)
        }
        return SymmetricKey(data: keyData)
    }

    private var keychainQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: self.keychainAccount,
        ]
    }

    private var vaultDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("SpeachText1.0", isDirectory: true)
            .appendingPathComponent("RecoveryVault", isDirectory: true)
    }

    private var vaultFileURL: URL {
        self.vaultDirectoryURL.appendingPathComponent("vault.aesgcm", isDirectory: false)
    }
}

private enum RecoveryVaultError: LocalizedError {
    case encryptionFailed
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "The encrypted vault could not be assembled."
        case .keychain(let status):
            return "The Recovery Vault key could not be accessed (OSStatus \(status))."
        }
    }
}
