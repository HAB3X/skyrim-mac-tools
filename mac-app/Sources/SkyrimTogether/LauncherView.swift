import AppKit
import LauncherCore
import SwiftUI

struct LauncherView: View {
    @Environment(Launcher.self) private var launcher
    @AppStorage("edition") private var edition = Edition.plus

    var body: some View {
        VStack(spacing: 0) {
            switch launcher.scripts {
            case .success:
                actions
                    .padding(20)
                SetupList(items: launcher.checkItems, edition: launcher.checkedEdition)
            case .failure(let problem):
                FolderMissingView(problem: problem)
            }
            Divider()
            StatusBar(status: launcher.status, busy: launcher.activity != nil)
        }
        .frame(minWidth: 460, minHeight: 480)
        .task { await launcher.check(edition) }
        .onChange(of: edition) { Task { await launcher.check(edition) } }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Skyrim Together")
                    .font(.title2.weight(.semibold))
                Spacer()
                Picker("Build", selection: $edition) {
                    ForEach(Edition.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .help("Base is the official 1.8.4 release; Plus adds the host world and Friends need my mods")
            }

            Button {
                Task { await launcher.play(edition) }
            } label: {
                Label(launcher.activity == .starting ? "Starting…" : "Play \(edition.gameName)", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            .keyboardShortcut(.defaultAction)
            .disabled(launcher.activity != nil)

            if edition == .plus, let update = launcher.availableUpdate {
                HStack {
                    Label("Skyrim Together Plus \(update.tag) is out", systemImage: "arrow.down.circle")
                    Spacer()
                    Button(launcher.activity == .updating ? "Updating…" : "Update to \(update.shortName)") {
                        Task { await launcher.installUpdate(update) }
                    }
                    .disabled(launcher.activity != nil)
                    .help("Downloads \(launcher.megabytes(update.bytes)), checks it and installs it; the current build is kept to go back to")
                }
            }

            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Button {
                        Task { await launcher.host(edition) }
                    } label: {
                        Label(launcher.hostRunning ? "Host Window Open" : "Host a Game", systemImage: "person.2")
                            .frame(maxWidth: .infinity)
                }
                .disabled(launcher.hostRunning)
                .help("Opens Skyrim Together Host: server name, password, who is connected, Kick and Ban")

                Button {
                    Task { await launcher.check(edition) }
                } label: {
                    Label("Check Setup", systemImage: "checklist").frame(maxWidth: .infinity)
                }
                .keyboardShortcut("r")
                .disabled(launcher.activity != nil)
                }
                GridRow {
                    Button {
                        Task { await launcher.fixInput(edition) }
                    } label: {
                        Label("Fix Mouse & Keyboard", systemImage: "computermouse").frame(maxWidth: .infinity)
                }
                .disabled(launcher.activity != nil)
                .help("When the running game ignores the mouse or keyboard: brings it to the front and gives it the input again, no restart")

                Button {
                    Task { await launcher.collectLogs(edition) }
                } label: {
                    Label("Collect Logs", systemImage: "doc.zipper").frame(maxWidth: .infinity)
                }
                .disabled(launcher.activity != nil)
                .help("Zips the game's logs and crash reports to the Desktop, without saves or passwords")
                }
            }
            .controlSize(.large)
        }
    }
}

/// The last check's lines, with the firewall fix ready to copy.
private struct SetupList: View {
    let items: [CheckItem]
    let edition: Edition?

    var body: some View {
        Form {
            Section(edition.map { "Setup for \($0.gameName)" } ?? "Setup") {
                if items.isEmpty {
                    Text("Not checked yet.").foregroundStyle(.secondary)
                }
                ForEach(items) { CheckRow(item: $0) }
            }
        }
        .formStyle(.grouped)
    }
}

private struct CheckRow: View {
    let item: CheckItem
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(item.text).textSelection(.enabled)
            } icon: {
                Image(systemName: symbol).foregroundStyle(colour)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(spokenKind): \(item.text)")

            if let command = item.command {
                // One line that scrolls sideways: wrapped, the command's paths break in the middle and read wrong
                ScrollView(.horizontal) {
                    Text(command)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                }
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
                .padding(.leading, 28)
                HStack {
                    Text("Paste it into Terminal; it asks for your Mac password.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(copied ? "Copied" : "Copy Command", systemImage: copied ? "checkmark" : "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command, forType: .string)
                        copied = true
                    }
                    .accessibilityLabel("Copy the Terminal command")
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 2)
    }

    private var symbol: String {
        switch item.kind {
        case .ok: "checkmark.circle.fill"
        case .missing, .failure: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle"
        }
    }

    private var colour: Color {
        switch item.kind {
        case .ok: .green
        case .missing, .failure: .red
        case .warning: .orange
        case .info: .secondary
        }
    }

    private var spokenKind: String {
        switch item.kind {
        case .ok: "Ready"
        case .missing: "Missing"
        case .failure: "Failed"
        case .warning: "Warning"
        case .info: "Note"
        }
    }
}

private struct StatusBar: View {
    let status: Launcher.Status
    let busy: Bool

    var body: some View {
        HStack(spacing: 8) {
            if busy {
                ProgressView().controlSize(.small)
            }
            Text(status.text)
                .foregroundStyle(status.tone == .problem ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Shown when the launch/ folder can't be found (the app was moved off the machine it was built on).
private struct FolderMissingView: View {
    @Environment(Launcher.self) private var launcher
    let problem: ScriptFolder.LocateError

    var body: some View {
        ContentUnavailableView {
            Label("Launch scripts not found", systemImage: "folder.badge.questionmark")
        } description: {
            Text(explanation)
        } actions: {
            Button("Choose Launch Folder…") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.message = "Choose the launch folder of skyrim-mac-tools (it holds skyrim-together.sh)."
                if panel.runModal() == .OK, let url = panel.url { launcher.useFolder(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }

    private var explanation: String {
        switch problem {
        case .notConfigured:
            "This copy wasn't built with build.sh, so it doesn't know where skyrim-mac-tools is."
        case .missingScripts(let path, let missing):
            "\(path) is missing \(missing.joined(separator: ", "))."
        }
    }
}
