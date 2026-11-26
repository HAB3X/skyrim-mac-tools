import AppKit
import SwiftUI

@main
struct SkyrimTogetherApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var launcher = Launcher()

    var body: some Scene {
        Window("Skyrim Together", id: "main") {
            LauncherView()
                .environment(launcher)
                .tint(.frost)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 540, height: 680)
    }
}

/// One window: closing it quits, like a game launcher. A running game or host window keeps running.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

extension Color {
    /// The app's one accent: the cold blue-grey of Skyrim's menus and steel, a little lighter in dark mode (white text on it stays above 3:1).
    static let frost = Color(nsColor: NSColor(name: "frost") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.36, green: 0.52, blue: 0.64, alpha: 1)
            : NSColor(srgbRed: 0.22, green: 0.38, blue: 0.50, alpha: 1)
    })
}
