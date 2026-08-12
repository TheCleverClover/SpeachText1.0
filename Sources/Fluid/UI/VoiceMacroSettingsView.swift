import AppKit
import SwiftUI

struct VoiceMacroSettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editingMacro: VoiceMacro?
    @State private var isAddingMacro = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Voice Macros", systemImage: "waveform.badge.plus")
                        .font(.title2.weight(.semibold))
                    Text("Run exact, deterministic actions from normal dictation without an AI provider.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: self.$settings.voiceMacrosEnabled)
                    .toggleStyle(.switch)
            }

            GroupBox("Safety") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Require the word “macro” before every trigger", isOn: self.$settings.voiceMacrosRequirePrefix)
                    Text(self.settings.voiceMacrosRequirePrefix
                         ? "Example: say “macro open finder.” The complete phrase must match exactly."
                         : "The complete trigger phrase must match exactly. Prefix protection is off.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Application, website, and Apple Shortcut actions ask for confirmation by default. Privacy Lock blocks non-text macros in protected apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            GroupBox("Configured macros") {
                VStack(spacing: 0) {
                    if self.settings.voiceMacros.isEmpty {
                        ContentUnavailableView(
                            "No Voice Macros",
                            systemImage: "waveform.slash",
                            description: Text("Add an exact trigger phrase and a safe action.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 210)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(self.settings.voiceMacros) { macro in
                                    self.macroRow(macro)
                                }
                            }
                            .padding(8)
                        }
                        .frame(minHeight: 210, maxHeight: 310)
                    }
                }
            }

            HStack {
                Button {
                    self.isAddingMacro = true
                } label: {
                    Label("Add Macro", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button("Restore Starter Macros") {
                    self.settings.voiceMacros = VoiceMacroDefaults.items
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") { self.dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 700, minHeight: 590)
        .sheet(isPresented: self.$isAddingMacro) {
            VoiceMacroEditorView(
                macro: VoiceMacro(
                    name: "New Macro",
                    triggerPhrase: "",
                    actionKind: .insertText,
                    payload: "",
                    confirmBeforeRun: false
                ),
                title: "Add Voice Macro"
            ) { macro in
                var macros = self.settings.voiceMacros
                macros.append(macro)
                self.settings.voiceMacros = macros
            }
        }
        .sheet(item: self.$editingMacro) { macro in
            VoiceMacroEditorView(macro: macro, title: "Edit Voice Macro") { updated in
                var macros = self.settings.voiceMacros
                guard let index = macros.firstIndex(where: { $0.id == updated.id }) else { return }
                macros[index] = updated
                self.settings.voiceMacros = macros
            }
        }
    }

    @ViewBuilder
    private func macroRow(_ macro: VoiceMacro) -> some View {
        HStack(spacing: 12) {
            Image(systemName: macro.actionKind.systemImage)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(macro.isEnabled ? Color.accentColor : Color.secondary)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(macro.name)
                        .font(.headline)
                    if macro.confirmBeforeRun {
                        Label("Confirms", systemImage: "checkmark.shield")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(self.displayedTrigger(for: macro))
                    .font(.system(.callout, design: .monospaced))
                Text("\(macro.actionKind.displayName): \(macro.payload)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { macro.isEnabled },
                set: { enabled in self.setMacro(macro.id, enabled: enabled) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)

            Button {
                self.editingMacro = macro
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit macro")

            Button(role: .destructive) {
                self.deleteMacro(macro.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete macro")
        }
        .padding(10)
        .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 9))
    }

    private func displayedTrigger(for macro: VoiceMacro) -> String {
        self.settings.voiceMacrosRequirePrefix
            ? "macro \(macro.triggerPhrase)"
            : macro.triggerPhrase
    }

    private func setMacro(_ id: UUID, enabled: Bool) {
        var macros = self.settings.voiceMacros
        guard let index = macros.firstIndex(where: { $0.id == id }) else { return }
        macros[index].isEnabled = enabled
        self.settings.voiceMacros = macros
    }

    private func deleteMacro(_ id: UUID) {
        self.settings.voiceMacros = self.settings.voiceMacros.filter { $0.id != id }
    }
}

private struct VoiceMacroEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var macro: VoiceMacro
    @State private var validationMessage = ""
    let title: String
    let onSave: (VoiceMacro) -> Void

    init(macro: VoiceMacro, title: String, onSave: @escaping (VoiceMacro) -> Void) {
        self._macro = State(initialValue: macro)
        self.title = title
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(self.title)
                .font(.title2.weight(.semibold))

            Form {
                TextField("Name", text: self.$macro.name)
                TextField("Exact trigger phrase", text: self.$macro.triggerPhrase)

                Picker("Action", selection: self.$macro.actionKind) {
                    ForEach(VoiceMacro.ActionKind.allCases) { kind in
                        Label(kind.displayName, systemImage: kind.systemImage).tag(kind)
                    }
                }

                self.payloadEditor

                Toggle("Enabled", isOn: self.$macro.isEnabled)
                Toggle("Confirm before running", isOn: self.$macro.confirmBeforeRun)
            }
            .formStyle(.grouped)

            if !self.validationMessage.isEmpty {
                Label(self.validationMessage, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Text("Matching ignores capitalization, extra spaces, and trailing punctuation—but requires the complete phrase.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { self.dismiss() }
                Button("Save") { self.save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 570, minHeight: 470)
        .onChange(of: self.macro.actionKind) { _, kind in
            if kind == .insertText {
                self.macro.confirmBeforeRun = false
            } else {
                self.macro.confirmBeforeRun = true
            }
        }
    }

    @ViewBuilder
    private var payloadEditor: some View {
        switch self.macro.actionKind {
        case .insertText:
            VStack(alignment: .leading) {
                Text("Text to insert")
                TextEditor(text: self.$macro.payload)
                    .font(.body)
                    .frame(minHeight: 90)
                    .border(.quaternary)
            }
        case .openApplication:
            HStack {
                TextField("Application bundle identifier", text: self.$macro.payload)
                Button("Choose App…") { self.chooseApplication() }
            }
        case .openURL:
            TextField("HTTPS or HTTP address", text: self.$macro.payload)
        case .runShortcut:
            TextField("Exact Apple Shortcut name", text: self.$macro.payload)
        }
    }

    private func save() {
        self.macro.name = self.macro.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.macro.triggerPhrase = VoiceMacroMatcher.normalizedPhrase(self.macro.triggerPhrase)
        if self.macro.actionKind != .insertText {
            self.macro.payload = self.macro.payload.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !self.macro.name.isEmpty else {
            self.validationMessage = "Enter a macro name."
            return
        }
        guard !self.macro.triggerPhrase.isEmpty else {
            self.validationMessage = "Enter an exact trigger phrase."
            return
        }
        guard !self.macro.payload.isEmpty else {
            self.validationMessage = "Enter the action value."
            return
        }
        if self.macro.actionKind == .openURL {
            guard let url = URL(string: self.macro.payload),
                  let scheme = url.scheme?.lowercased(),
                  ["https", "http"].contains(scheme)
            else {
                self.validationMessage = "Enter a valid HTTP or HTTPS address."
                return
            }
        }

        self.onSave(self.macro)
        self.dismiss()
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application"
        panel.prompt = "Use App"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier,
              !bundleID.isEmpty
        else { return }
        self.macro.payload = bundleID
    }
}
