import AppKit
import Foundation

struct VoiceMacro: Codable, Equatable, Identifiable, Sendable {
    enum ActionKind: String, Codable, CaseIterable, Identifiable, Sendable {
        case insertText
        case openApplication
        case openURL
        case runShortcut

        var id: String { self.rawValue }

        var displayName: String {
            switch self {
            case .insertText: return "Insert Text"
            case .openApplication: return "Open Application"
            case .openURL: return "Open Website"
            case .runShortcut: return "Run Apple Shortcut"
            }
        }

        var systemImage: String {
            switch self {
            case .insertText: return "text.cursor"
            case .openApplication: return "app"
            case .openURL: return "safari"
            case .runShortcut: return "square.stack.3d.up.fill"
            }
        }
    }

    var id: UUID
    var name: String
    var triggerPhrase: String
    var actionKind: ActionKind
    var payload: String
    var isEnabled: Bool
    var confirmBeforeRun: Bool

    init(
        id: UUID = UUID(),
        name: String,
        triggerPhrase: String,
        actionKind: ActionKind,
        payload: String,
        isEnabled: Bool = true,
        confirmBeforeRun: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.triggerPhrase = triggerPhrase
        self.actionKind = actionKind
        self.payload = payload
        self.isEnabled = isEnabled
        self.confirmBeforeRun = confirmBeforeRun ?? (actionKind != .insertText)
    }
}

enum VoiceMacroDefaults {
    static let items: [VoiceMacro] = [
        VoiceMacro(
            id: UUID(uuidString: "36BC4E01-DB32-45DD-99CB-C23F58F48C08")!,
            name: "Open Finder",
            triggerPhrase: "open finder",
            actionKind: .openApplication,
            payload: "com.apple.finder",
            confirmBeforeRun: true
        ),
        VoiceMacro(
            id: UUID(uuidString: "B3194556-A849-49C9-99B6-F08EE62305D4")!,
            name: "Open Calendar",
            triggerPhrase: "open calendar",
            actionKind: .openApplication,
            payload: "com.apple.iCal",
            confirmBeforeRun: true
        ),
    ]
}

enum VoiceMacroOutcome: Sendable, Equatable {
    case insertText(String)
    case completed(String)
    case cancelled
    case failed(String)
}

enum VoiceMacroMatcher {
    static func matchingMacro(
        for transcription: String,
        macros: [VoiceMacro],
        requirePrefix: Bool
    ) -> VoiceMacro? {
        let normalizedInput = self.normalizedPhrase(transcription)
        guard !normalizedInput.isEmpty else { return nil }

        return macros.first { macro in
            guard macro.isEnabled else { return false }
            let trigger = self.normalizedPhrase(macro.triggerPhrase)
            guard !trigger.isEmpty else { return false }
            let expected = requirePrefix ? "macro \(trigger)" : trigger
            return normalizedInput == expected
        }
    }

    static func normalizedPhrase(_ value: String) -> String {
        let lowercased = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let stripped = lowercased.trimmingCharacters(in: CharacterSet.punctuationCharacters)
        return stripped
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

enum VoiceMacroService {
    static func match(_ transcription: String, settings: SettingsStore = .shared) -> VoiceMacro? {
        guard settings.voiceMacrosEnabled else { return nil }
        return VoiceMacroMatcher.matchingMacro(
            for: transcription,
            macros: settings.voiceMacros,
            requirePrefix: settings.voiceMacrosRequirePrefix
        )
    }

    static func execute(_ macro: VoiceMacro) async -> VoiceMacroOutcome {
        if macro.confirmBeforeRun {
            let approved = await MainActor.run { self.confirm(macro) }
            guard approved else { return .cancelled }
        }

        switch macro.actionKind {
        case .insertText:
            guard !macro.payload.isEmpty else { return .failed("The text macro is empty.") }
            return .insertText(macro.payload)

        case .openApplication:
            let bundleID = macro.payload.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bundleID.isEmpty else {
                return .failed("The selected application is not installed.")
            }
            let installedApplicationURL = await MainActor.run {
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            }
            guard let appURL = installedApplicationURL else {
                return .failed("The selected application is not installed.")
            }

            do {
                try await self.openApplication(at: appURL)
                return .completed("Opened \(macro.name).")
            } catch {
                return .failed(error.localizedDescription)
            }

        case .openURL:
            let value = macro.payload.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: value),
                  let scheme = url.scheme?.lowercased(),
                  ["https", "http"].contains(scheme)
            else {
                return .failed("Voice Macros only open valid HTTP or HTTPS addresses.")
            }
            let opened = await MainActor.run { NSWorkspace.shared.open(url) }
            return opened ? .completed("Opened \(url.host ?? "website").") : .failed("macOS could not open that address.")

        case .runShortcut:
            let shortcutName = macro.payload.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !shortcutName.isEmpty else { return .failed("The Apple Shortcut name is empty.") }
            return await self.runShortcut(named: shortcutName)
        }
    }

    @MainActor
    private static func confirm(_ macro: VoiceMacro) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Run voice macro ‘\(macro.name)’?"
        alert.informativeText = self.confirmationDetail(for: macro)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Run Macro")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func confirmationDetail(for macro: VoiceMacro) -> String {
        switch macro.actionKind {
        case .insertText:
            return "Insert the configured text into the active application."
        case .openApplication:
            return "Open application with bundle identifier \(macro.payload)."
        case .openURL:
            return "Open \(macro.payload) in the default browser."
        case .runShortcut:
            return "Run the Apple Shortcut named \(macro.payload). Shortcuts may perform additional actions."
        }
    }

    @MainActor
    private static func openApplication(at url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func runShortcut(named name: String) async -> VoiceMacroOutcome {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name]
            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    return .completed("Ran Apple Shortcut \(name).")
                }
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return .failed(errorText?.isEmpty == false ? errorText! : "The Apple Shortcut failed.")
            } catch {
                return .failed(error.localizedDescription)
            }
        }.value
    }
}
