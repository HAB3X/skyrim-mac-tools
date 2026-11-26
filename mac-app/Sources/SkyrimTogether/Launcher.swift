import AppKit
import LauncherCore
import Observation

/// What the app is doing and what it last found. Owned by the App, so a running check or host survives the window.
@MainActor
@Observable
final class Launcher {
    enum Activity: Equatable { case checking, starting, collecting }

    struct Status: Equatable {
        enum Tone { case neutral, success, problem }
        var text: String
        var tone: Tone = .neutral
    }

    static let folderKey = "launchFolder"

    private(set) var scripts: Result<ScriptFolder, ScriptFolder.LocateError>
    private(set) var activity: Activity?
    private(set) var hostRunning = false
    private(set) var checkItems: [CheckItem] = []
    private(set) var checkedEdition: Edition?
    private(set) var status = Status(text: "Ready")

    init() {
        scripts = Launcher.locateScripts()
    }

    /// The launch/ folder: the one the user picked, else the repo's, which build.sh writes into Info.plist.
    private static func locateScripts() -> Result<ScriptFolder, ScriptFolder.LocateError> {
        let chosen = UserDefaults.standard.string(forKey: folderKey)
        let built = Bundle.main.object(forInfoDictionaryKey: "STLaunchFolder") as? String
        guard let path = chosen ?? built else { return .failure(.notConfigured) }
        do { return .success(try ScriptFolder(path: path)) } catch { return .failure(error) }
    }

    func useFolder(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: Launcher.folderKey)
        scripts = Launcher.locateScripts()
    }

    // MARK: Actions

    func check(_ edition: Edition) async {
        guard activity == nil, case .success(let folder) = scripts else { return }
        activity = .checking
        status = Status(text: "Checking the setup for \(edition.gameName)…")
        defer { activity = nil }
        guard let result = await run(folder.url(for: .together), ["check"], edition) else { return }
        checkItems = CheckItem.parse(result.output)
        checkedEdition = edition
        let missing = checkItems.filter { $0.kind == .missing || $0.kind == .failure }.count
        let warnings = checkItems.filter { $0.kind == .warning }.count
        status = switch (missing, warnings) {
        case (0, 0): Status(text: "\(edition.gameName) is ready to play.", tone: .success)
        case (0, _): Status(text: "Ready to play. \(count(warnings, "warning")) about hosting.", tone: .success)
        default: Status(text: "\(count(missing, "thing")) to fix before \(edition.gameName) can start.", tone: .problem)
        }
    }

    func play(_ edition: Edition) async {
        guard activity == nil, case .success(let folder) = scripts else { return }
        activity = .starting
        defer { activity = nil }
        if await gameIsRunning() {
            status = Status(text: "Skyrim Together is already running.", tone: .problem)
            return
        }
        status = Status(text: "Starting \(edition.gameName)…")
        guard let result = await run(folder.url(for: .play), ["together"], edition) else { return }
        let items = CheckItem.parse(result.output)
        if result.status == 0 {
            status = Status(text: "\(edition.gameName) is starting. Its window comes to the front when it opens.", tone: .success)
        } else {
            checkItems = items
            checkedEdition = edition
            let reason = items.last { $0.kind == .failure }?.text ?? "the launcher stopped with status \(result.status)"
            status = Status(text: "Couldn't start: \(reason)", tone: .problem)
        }
    }

    func host(_ edition: Edition) async {
        guard !hostRunning, case .success(let folder) = scripts else { return }
        hostRunning = true
        status = Status(text: "Opening the host window for \(edition.gameName)…")
        defer { hostRunning = false }
        guard let result = await run(folder.url(for: .hostApp), [], edition) else { return }
        status = result.status == 0
            ? Status(text: "The host window was closed.")
            : Status(text: "The host window couldn't open (status \(result.status)). See ~/Games/skyrim/logs/host-app.log.",
                     tone: .problem)
    }

    func collectLogs(_ edition: Edition) async {
        guard activity == nil, case .success(let folder) = scripts else { return }
        activity = .collecting
        status = Status(text: "Collecting logs…")
        defer { activity = nil }
        guard let result = await run(folder.url(for: .collectLogs), [], edition) else { return }
        guard result.status == 0, let zip = LaunchScript.collectedZip(in: result.output) else {
            let reason = CheckItem.parse(result.output).last?.text ?? "status \(result.status)"
            status = Status(text: "Couldn't collect the logs: \(reason)", tone: .problem)
            return
        }
        let url = URL(filePath: zip)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        status = Status(text: "Saved \(url.lastPathComponent) to the Desktop.", tone: .success)
    }

    // MARK: Helpers

    /// Runs a script; a script that can't start at all is reported in the status line and returns nil.
    private func run(_ script: URL, _ arguments: [String], _ edition: Edition) async -> ScriptResult? {
        do {
            return try await ScriptRunner.run(script, arguments: arguments, extraEnvironment: ["ST_VERSION": edition.rawValue])
        } catch {
            status = Status(text: "Couldn't run \(script.lastPathComponent): \(error.localizedDescription)", tone: .problem)
            return nil
        }
    }

    /// The same process skyrim-together.sh waits for before bringing the game to the front. If pgrep itself can't
    /// run, this says "not running" and the game starts as if this guard weren't here.
    private func gameIsRunning() async -> Bool {
        let result = try? await ScriptRunner.run(URL(filePath: "/usr/bin/pgrep"), arguments: ["-f", "SkyrimTogether.exe --exePath"])
        return result?.status == 0
    }

    private func count(_ n: Int, _ noun: String) -> String {
        n == 1 ? "1 \(noun)" : "\(n) \(noun)s"
    }
}
