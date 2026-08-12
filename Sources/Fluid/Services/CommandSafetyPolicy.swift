import Foundation

enum CommandSafetyPolicy {
    static func requiresConfirmation(
        command: String,
        workingDirectory: String?,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let cmd = trimmed.lowercased()
        guard !cmd.isEmpty else { return true }

        if let workingDirectory,
           !workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            let resolvedDirectory = URL(fileURLWithPath: workingDirectory)
                .standardizedFileURL.path
            let home = homeDirectory.standardizedFileURL.path
            if resolvedDirectory != home, !resolvedDirectory.hasPrefix(home + "/") {
                return true
            }
        }

        let shellControlPatterns = [
            "\n", "\r", ";", "&&", "||", "`", "$(", ">", "<", "|", "xargs", "eval ", "source ",
        ]
        if shellControlPatterns.contains(where: { cmd.contains($0) }) {
            return true
        }

        let protectedPrefixes = [
            "rm ", "rmdir ", "mv ", "cp ", "mkdir ", "touch ", "ln ",
            "sudo ", "su ", "doas ", "kill ", "pkill ", "killall ",
            "chmod ", "chown ", "chgrp ", "xattr ", "codesign ", "security ",
            "dd ", "diskutil ", "mkfs", "format ", "truncate ", "shred ",
            "curl ", "wget ", "ssh ", "scp ", "sftp ", "nc ", "netcat ",
            "brew ", "port ", "npm ", "pnpm ", "yarn ", "pip ", "pip3 ",
            "gem ", "cargo ", "go install ", "softwareupdate ", "installer ",
            "osascript ", "open ", "shortcuts ", "launchctl ", "defaults ",
            "plutil ", "sqlite3 ", "python ", "python3 ", "ruby ", "node ",
            "bash ", "zsh ", "sh ", "fish ", "git ", "svn ",
            "cat ", "head ", "tail ", "less ", "more ", "sed ", "awk ",
            "find ", "mdfind ", "grep ", "rg ", "tar ", "zip ", "unzip ",
        ]
        if protectedPrefixes.contains(where: {
            cmd == $0.trimmingCharacters(in: .whitespaces) || cmd.hasPrefix($0)
        }) {
            return true
        }

        let lowRiskCommands = [
            "pwd", "date", "whoami", "uname", "sw_vers", "uptime", "arch",
            "echo", "printf", "which", "command -v", "true", "false",
        ]
        if lowRiskCommands.contains(where: { cmd == $0 || cmd.hasPrefix($0 + " ") }) {
            return false
        }

        return true
    }
}
