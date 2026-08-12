import AppKit
import SwiftUI

struct PrivacyLockSettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var manualBundleID = ""
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Privacy Lock", systemImage: "lock.shield.fill")
                        .font(.title2.weight(.semibold))
                    Text("Keep dictation local and suppress risky actions in protected applications.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: self.$settings.privacyLockEnabled)
                    .toggleStyle(.switch)
            }

            GroupBox("Protection behavior") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Command Mode and Rewrite Mode are blocked.", systemImage: "terminal.fill")
                    Label("Remote AI enhancement, transcript history, saved audio, and clipboard copies are skipped.", systemImage: "icloud.slash.fill")
                    Label("On-device speech recognition and Speach Intelligence remain available.", systemImage: "cpu.fill")

                    Toggle(
                        "Protect private-browser and credential-related windows",
                        isOn: self.$settings.privacyLockProtectSensitiveWindows
                    )
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            GroupBox("Built-in protected applications") {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)], spacing: 8) {
                        ForEach(PrivacyLockPolicy.builtInProtectedApplications, id: \.bundleID) { application in
                            Label(application.name, systemImage: "checkmark.shield")
                                .font(.callout)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .frame(height: 100)
            }

            GroupBox("Additional protected applications") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("Bundle identifier, for example com.example.app", text: self.$manualBundleID)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { self.addManualBundleID() }
                        Button("Add") { self.addManualBundleID() }
                            .disabled(self.manualBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Choose App…") { self.chooseApplication() }
                    }

                    if self.settings.privacyLockCustomBundleIDs.isEmpty {
                        Text("No additional applications have been added.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(self.settings.privacyLockCustomBundleIDs, id: \.self) { bundleID in
                                    HStack {
                                        Image(systemName: "app.badge.checkmark")
                                            .foregroundStyle(.secondary)
                                        Text(bundleID)
                                            .font(.system(.callout, design: .monospaced))
                                            .textSelection(.enabled)
                                        Spacer()
                                        Button(role: .destructive) {
                                            self.removeBundleID(bundleID)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Remove protected application")
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }

                    if !self.statusMessage.isEmpty {
                        Text(self.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }

            HStack {
                Text("Privacy Lock is enabled by default. You can disable it globally or remove individual custom applications at any time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") { self.dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 640, minHeight: 580)
    }

    private func addManualBundleID() {
        let bundleID = self.manualBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundleID.isEmpty else { return }
        var values = self.settings.privacyLockCustomBundleIDs
        values.append(bundleID)
        self.settings.privacyLockCustomBundleIDs = values
        self.manualBundleID = ""
        self.statusMessage = "Added \(bundleID)."
    }

    private func removeBundleID(_ bundleID: String) {
        self.settings.privacyLockCustomBundleIDs.removeAll { $0.caseInsensitiveCompare(bundleID) == .orderedSame }
        self.statusMessage = "Removed \(bundleID)."
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application to protect"
        panel.prompt = "Protect App"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier, !bundleID.isEmpty else {
            self.statusMessage = "That application does not expose a bundle identifier."
            return
        }

        var values = self.settings.privacyLockCustomBundleIDs
        values.append(bundleID)
        self.settings.privacyLockCustomBundleIDs = values
        self.statusMessage = "Added \(bundleID)."
    }
}
