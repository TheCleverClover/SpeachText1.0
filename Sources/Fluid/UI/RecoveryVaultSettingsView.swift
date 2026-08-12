import SwiftUI

struct RecoveryVaultSettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var vault = RecoveryVaultStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pendingRestore: RecoveryVaultRecord?
    @State private var showClearConfirmation = false
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Recovery Vault", systemImage: "externaldrive.badge.timemachine")
                        .font(.title2.weight(.semibold))
                    Text("Recover recent SpeachText1.0 insertions without exposing them to cloud services.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: self.$settings.recoveryVaultEnabled)
                    .toggleStyle(.switch)
            }

            GroupBox("Protection and retention") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Vault records are AES-256-GCM encrypted with a key stored in macOS Keychain.", systemImage: "lock.fill")
                    Label("Privacy Lock contexts are never added to the vault.", systemImage: "lock.shield")
                    Label("Vault contents and the encryption key are excluded from settings backups.", systemImage: "externaldrive.badge.xmark")

                    Toggle(
                        "Enable instant undo with Command-Option-Z",
                        isOn: self.$settings.recoveryVaultInstantUndoEnabled
                    )
                    .padding(.top, 4)

                    Stepper(
                        "Keep records for \(self.settings.recoveryVaultRetentionDays) day\(self.settings.recoveryVaultRetentionDays == 1 ? "" : "s")",
                        value: self.$settings.recoveryVaultRetentionDays,
                        in: 1...30
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            GroupBox("Recent recoverable insertions") {
                if self.vault.records.isEmpty {
                    ContentUnavailableView(
                        "Recovery Vault is empty",
                        systemImage: "externaldrive",
                        description: Text("New external text insertions will appear here when the vault is enabled.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 230)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(self.vault.records) { record in
                                self.recordRow(record)
                            }
                        }
                        .padding(8)
                    }
                    .frame(minHeight: 230, maxHeight: 330)
                }
            }

            if !self.statusMessage.isEmpty {
                Text(self.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    self.undoLatest()
                } label: {
                    Label("Undo Latest", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderedProminent)
                .disabled(self.vault.latestRecoverableRecord == nil)

                Button("Clear Vault", role: .destructive) {
                    self.showClearConfirmation = true
                }
                .disabled(self.vault.records.isEmpty)

                Spacer()

                Button("Done") { self.dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 720, minHeight: 650)
        .onChange(of: self.settings.recoveryVaultRetentionDays) { _, _ in
            self.vault.reload()
        }
        .confirmationDialog(
            "Restore this text into \(self.pendingRestore?.appName ?? "the original application")?",
            isPresented: Binding(
                get: { self.pendingRestore != nil },
                set: { if !$0 { self.pendingRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Restore Text") {
                guard let record = self.pendingRestore else { return }
                self.pendingRestore = nil
                self.restore(record)
            }
            Button("Cancel", role: .cancel) {
                self.pendingRestore = nil
            }
        } message: {
            Text("SpeachText1.0 will activate the original running app and insert the encrypted record at its current focus location.")
        }
        .confirmationDialog(
            "Permanently clear Recovery Vault?",
            isPresented: self.$showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Vault", role: .destructive) {
                self.vault.clear()
                self.statusMessage = "Recovery Vault was cleared."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all encrypted recovery records from this Mac. The action cannot be undone.")
        }
    }

    @ViewBuilder
    private func recordRow(_ record: RecoveryVaultRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.undoneAt == nil ? "doc.text.fill" : "arrow.uturn.backward.circle.fill")
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(record.undoneAt == nil ? Color.accentColor : Color.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(record.appName.isEmpty ? "Unknown application" : record.appName)
                        .font(.headline)
                    Text(record.source.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                    if record.undoneAt != nil {
                        Text("Undone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(record.text)
                    .font(.callout)
                    .lineLimit(2)
                    .privacySensitive()

                Text(record.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Restore") {
                self.pendingRestore = record
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                self.vault.delete(record.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete encrypted record")
        }
        .padding(10)
        .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 9))
    }

    private func undoLatest() {
        guard let record = self.vault.latestRecoverableRecord else { return }
        Task { @MainActor in
            if await RecoveryVaultActions.undo(record) {
                self.statusMessage = "The latest insertion was undone in \(record.appName)."
            } else {
                self.statusMessage = "Could not reach the original app. Open it and try Restore instead."
            }
        }
    }

    private func restore(_ record: RecoveryVaultRecord) {
        Task { @MainActor in
            if await RecoveryVaultActions.restore(record) {
                self.statusMessage = "Restored text in \(record.appName)."
            } else {
                self.statusMessage = "Could not restore because \(record.appName) is not running."
            }
        }
    }
}
