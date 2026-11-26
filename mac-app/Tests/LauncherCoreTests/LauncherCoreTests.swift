import Foundation
import Testing
@testable import LauncherCore

// Real output of `skyrim-together.sh check` on this Mac (2026-11-26), with the firewall warning
private let checkOutput = """
    OK   Wine runtime
    OK   Skyrim Together 1.8.4 files
    OK   Skyrim at /Users/me/Games/skyrim/prefix/drive_c/GOG Games/Skyrim Special Edition
    MISS game version 1.6.640.0 — Skyrim Together 1.8.4 needs 1.6.1179.0
    WARN the Mac firewall blocks Wine: friends can't join a game you host. In Terminal:
           sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /w/wine && sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /w/wine
    """

@Test func checkLinesBecomeItemsWithTheirKind() {
    let items = CheckItem.parse(checkOutput)
    #expect(items.map(\.kind) == [.ok, .ok, .ok, .missing, .warning])
    #expect(items[0].text == "Wine runtime")
    #expect(items[3].text == "Game version 1.6.640.0 — Skyrim Together 1.8.4 needs 1.6.1179.0")
}

@Test func anIndentedLineIsTheCommandOfTheLineAboveIt() {
    let firewall = CheckItem.parse(checkOutput)[4]
    #expect(firewall.text == "The Mac firewall blocks Wine: friends can't join a game you host.")
    #expect(firewall.command?.hasPrefix("sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /w/wine") == true)
}

@Test func failAndUnrecognisedLinesAreKeptNotDropped() {
    let items = CheckItem.parse("installing x into y\nFAIL not ready (see MISS lines above)\n\n")
    #expect(items.map(\.kind) == [.info, .failure])
    #expect(items[0].text == "Installing x into y")
    #expect(items[1].text == "Not ready (see MISS lines above)")
}

@Test func theScriptFolderMustHoldEveryScript() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let scripts = LaunchScript.allCases.map { folder.appending(path: $0.rawValue) }
    for script in scripts.dropLast() { FileManager.default.createFile(atPath: script.path, contents: Data()) }

    #expect(throws: ScriptFolder.LocateError.missingScripts(folder.path, [LaunchScript.allCases.last!.rawValue])) {
        try ScriptFolder(path: folder.path)
    }
    FileManager.default.createFile(atPath: scripts.last!.path, contents: Data())
    #expect(try ScriptFolder(path: folder.path).url(for: .play).path == scripts[LaunchScript.allCases.firstIndex(of: .play)!].path)
}

@Test func theLastPathTheCollectorPrintsIsTheZip() {
    #expect(LaunchScript.collectedZip(in: "WARN could not copy x\n/Users/me/Desktop/SkyrimTogether-logs-1.zip\n")
        == "/Users/me/Desktop/SkyrimTogether-logs-1.zip")
    #expect(LaunchScript.collectedZip(in: "FAIL could not write\n") == nil)
}

// skyrim-together.sh exits while the game it started keeps the output open; the answer must not wait for the game
@Test func theResultComesWhenTheScriptExitsNotWhenItsChildrenDo() async throws {
    let script = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).sh")
    try "#!/bin/bash\necho started\n/bin/sleep 20 &\necho FAIL done\nexit 3\n".write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    defer { try? FileManager.default.removeItem(at: script) }

    let clock = ContinuousClock()
    let start = clock.now
    let result = try await ScriptRunner.run(script, extraEnvironment: ["ST_VERSION": "x"])
    #expect(clock.now - start < .seconds(5))
    #expect(result.status == 3)
    #expect(result.output == "started\nFAIL done\n")
}

@Test func anUpdateLineNamesTheReleaseItsSizeAndWhatIsInstalled() {
    let update = PlusUpdate.parse("UPDATE v1.8.4-plus.4 346133235 v1.8.4-plus.3\n")
    #expect(update == PlusUpdate(tag: "v1.8.4-plus.4", bytes: 346_133_235, installed: "v1.8.4-plus.3"))
    #expect(update?.shortName == "plus.4")
    #expect(PlusUpdate.parse("UPDATE v1.8.4-plus.1 345489304 none")?.installed == nil)
}

// Real output of `skyrim-together.sh update check` with plus.3 installed (2026-11-26), and a failed check
@Test func noUpdateWhenTheCheckSaysOKOrFailed() {
    #expect(PlusUpdate.parse("OK   Skyrim Together Plus v1.8.4-plus.3 is the newest release\n") == nil)
    #expect(PlusUpdate.parse("FAIL could not read the Skyrim Together releases from GitHub\n") == nil)
    #expect(PlusUpdate.parse("UPDATE v1.8.4-plus.4 lots none") == nil)
}

private let firewallCommand = "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Users/me/Games/skyrim/wine/bin/wine"
    + " && sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Users/me/Games/skyrim/wine/bin/wine"

@Test func theFirewallFixRunsTheSameCommandsAsAdministratorWithoutSudo() throws {
    let arguments = try FirewallFix.osascriptArguments(fromSudo: firewallCommand)
    #expect(arguments == ["-e", "do shell script \"/usr/libexec/ApplicationFirewall/socketfilterfw --add /Users/me/Games/skyrim/wine/bin/wine"
        + " && /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Users/me/Games/skyrim/wine/bin/wine\" with administrator privileges"])
}

// The script prints paths with spaces escaped by printf %q; the backslash must survive into the AppleScript string
@Test func aPathWithASpaceStaysOneArgument() throws {
    let command = "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Users/a\\ b/wine"
    #expect(try FirewallFix.shellCommand(fromSudo: command) == "/usr/libexec/ApplicationFirewall/socketfilterfw --add /Users/a\\ b/wine")
    #expect(try FirewallFix.osascriptArguments(fromSudo: command)[1]
        == "do shell script \"/usr/libexec/ApplicationFirewall/socketfilterfw --add /Users/a\\\\ b/wine\" with administrator privileges")
}

@Test func onlySocketfilterfwCommandsAreRunAsAdministrator() {
    for command in ["sudo rm -rf /", "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add x; rm -rf /",
                    "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add $(whoami)", "/usr/libexec/ApplicationFirewall/socketfilterfw --add x",
                    firewallCommand + " && sudo rm -rf /"] {
        #expect(throws: FirewallFix.BuildError.notAFirewallCommand(command)) { try FirewallFix.shellCommand(fromSudo: command) }
    }
}

// Dry run: AppleScript compiles the script (osacompile), which checks the quoting without running anything
@Test func theAppleScriptCompiles() async throws {
    let output = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).scpt")
    defer { try? FileManager.default.removeItem(at: output) }
    let script = try FirewallFix.osascriptArguments(fromSudo: firewallCommand.replacingOccurrences(of: "/me/", with: "/a\\ \"b/"))[1]
    let result = try await ScriptRunner.run(URL(filePath: "/usr/bin/osacompile"), arguments: ["-o", output.path, "-e", script])
    #expect(result.status == 0, "\(result.output)")
}
