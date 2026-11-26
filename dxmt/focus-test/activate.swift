// activate.swift <pid>|front: make that process the active app (NSRunningApplication, no Automation permission);
// "front" prints the pid of the active app.
import AppKit
let arg = CommandLine.arguments.dropFirst().first ?? "front"
if arg == "front" { print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0); exit(0) }
guard let pid = Int32(arg), let app = NSRunningApplication(processIdentifier: pid) else { print("no app \(arg)"); exit(1) }
print(app.activate(options: [.activateAllWindows]) ? "activated \(pid)" : "refused \(pid)")
