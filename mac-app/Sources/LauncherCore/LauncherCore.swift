import Foundation

/// Which Skyrim Together build the scripts use (their ST_VERSION).
public enum Edition: String, CaseIterable, Identifiable, Sendable {
    case base = "1.8.4"
    case plus = "1.8.4-plus"

    public var id: String { rawValue }
    public var title: String { self == .base ? "Base" : "Plus" }
    public var gameName: String { self == .base ? "Skyrim Together" : "Skyrim Together Plus" }
}

/// The scripts in the repo's launch/ folder that the app runs.
public enum LaunchScript: String, CaseIterable, Sendable {
    case play = "skyrim-play.sh"            // `together` argument: Skyrim Together at the screen's size
    case hostApp = "skyrim-host-app.sh"     // the Windows host window under Wine; runs until it's closed
    case together = "skyrim-together.sh"    // `check`: one OK/MISS/WARN line per requirement
    case collectLogs = "collect-logs.sh"    // prints the zip's path last

    /// collect-logs.sh prints the zip's path as its last line; anything else there means it failed.
    public static func collectedZip(in output: String) -> String? {
        let last = output.split(whereSeparator: \.isNewline).last.map(String.init)
        return last.flatMap { $0.hasPrefix("/") && $0.hasSuffix(".zip") ? $0 : nil }
    }
}

/// A folder holding every LaunchScript.
public struct ScriptFolder: Equatable, Sendable {
    public enum LocateError: Error, Equatable {
        case notConfigured
        case missingScripts(String, [String])
    }

    public let path: String

    public init(path: String) throws(LocateError) {
        let missing = LaunchScript.allCases.map(\.rawValue).filter {
            !FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent($0))
        }
        guard missing.isEmpty else { throw .missingScripts(path, missing) }
        self.path = path
    }

    public func url(for script: LaunchScript) -> URL {
        URL(filePath: path).appending(path: script.rawValue)
    }
}

/// One line of the scripts' status output: "OK   Wine runtime", "MISS ...", "WARN ...", "FAIL ...".
public struct CheckItem: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case ok, missing, warning, failure, info }

    public let id: Int
    public let kind: Kind
    public let text: String
    /// A command the line asks the user to run in Terminal (the indented line under it), e.g. the firewall fix.
    public var command: String?

    public init(id: Int, kind: Kind, text: String, command: String? = nil) {
        self.id = id
        self.kind = kind
        self.text = text
        self.command = command
    }

    private static let prefixes: [(String, Kind)] = [("OK ", .ok), ("MISS ", .missing), ("WARN ", .warning), ("FAIL ", .failure)]

    public static func parse(_ output: String) -> [CheckItem] {
        var items: [CheckItem] = []
        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if line.first?.isWhitespace == true, !items.isEmpty {
                items[items.count - 1].command = trimmed
                continue
            }
            let (kind, rest) = prefixes.first { line.hasPrefix($0.0) }
                .map { ($0.1, String(line.dropFirst($0.0.count))) } ?? (.info, line)
            items.append(CheckItem(id: items.count, kind: kind, text: sentence(rest), command: nil))
        }
        return items
    }

    /// "the Mac firewall blocks Wine: ... In Terminal:" -> "The Mac firewall blocks Wine: ..." (the command follows)
    private static func sentence(_ text: String) -> String {
        var text = text.trimmingCharacters(in: .whitespaces)
        if text.hasSuffix(" In Terminal:") { text.removeLast(" In Terminal:".count) }
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

/// A newer Plus release, as `skyrim-together.sh update check` reports it: "UPDATE v1.8.4-plus.4 346133235 v1.8.4-plus.3"
/// (tag, zip size in bytes, the installed build's version or "none"). An up-to-date check prints an OK line instead.
public struct PlusUpdate: Equatable, Sendable {
    public let tag: String
    public let bytes: Int64
    public let installed: String?

    /// "plus.4"
    public var shortName: String { tag.split(separator: "-").last.map(String.init) ?? tag }
    /// "Install plus.5" when no Plus build is installed yet, else "Update to plus.5".
    public var actionTitle: String { installed == nil ? "Install \(shortName)" : "Update to \(shortName)" }

    public static func parse(_ output: String) -> PlusUpdate? {
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ").map(String.init)
            guard fields.count == 4, fields[0] == "UPDATE", let bytes = Int64(fields[2]) else { continue }
            return PlusUpdate(tag: fields[1], bytes: bytes, installed: fields[3] == "none" ? nil : fields[3])
        }
        return nil
    }
}

/// The firewall fix that `skyrim-together.sh check` prints for Terminal ("sudo …socketfilterfw --add … && sudo
/// …socketfilterfw --unblockapp …"), run instead through osascript's `do shell script … with administrator
/// privileges`, so macOS asks for the user's own password in its own dialog. Only socketfilterfw commands are accepted:
/// this runs as root.
public enum FirewallFix {
    public enum BuildError: Error, Equatable {
        case notAFirewallCommand(String)
    }

    static let tool = "/usr/libexec/ApplicationFirewall/socketfilterfw"

    /// The shell command without its `sudo`s: "socketfilterfw --add X && socketfilterfw --unblockapp X"
    public static func shellCommand(fromSudo command: String) throws(BuildError) -> String {
        let steps = command.components(separatedBy: " && ")
        let unprivileged = steps.map { $0.trimmingCharacters(in: .whitespaces) }.map { step -> String? in
            guard step.hasPrefix("sudo \(tool) "), !step.contains(";"), !step.contains("|"), !step.contains("`"),
                  !step.contains("$(") else { return nil }
            return String(step.dropFirst("sudo ".count))
        }
        guard !steps.isEmpty, unprivileged.allSatisfy({ $0 != nil }) else { throw .notAFirewallCommand(command) }
        return unprivileged.compactMap { $0 }.joined(separator: " && ")
    }

    /// osascript's arguments: `-e`, then the AppleScript with the shell command as an escaped string literal
    public static func osascriptArguments(fromSudo command: String) throws(BuildError) -> [String] {
        let shell = try shellCommand(fromSudo: command)
        let literal = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return ["-e", "do shell script \"\(literal)\" with administrator privileges"]
    }
}
