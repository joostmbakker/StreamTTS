import SwiftUI
import AppKit

/// StreamTTS Demo — a minimal macOS app for testing streaming text-to-speech.
@main
struct StreamTTSDemoApp: App {
    /// Delegate that activates the app on launch so it receives keyboard focus
    /// even when started from the terminal via `swift run`.
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 550, minHeight: 450)
        }
        .defaultSize(width: 600, height: 500)
    }
}

/// Ensures the app becomes the frontmost process on launch.
///
/// Without this, `swift run` launches the window but macOS keeps keyboard
/// focus on the terminal/browser that was previously active.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
