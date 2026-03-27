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

/// Ensures the app becomes a regular GUI application and receives keyboard focus.
///
/// SPM executables lack an `.app` bundle and `Info.plist`, so macOS does not
/// automatically treat them as regular GUI applications. Without explicitly
/// setting the activation policy to `.regular`, the window appears but keyboard
/// input is routed to the previously active app (Terminal, browser, etc.).
/// The "Cannot index window tabs due to missing main bundle identifier" log
/// is a cosmetic side-effect of the missing bundle — harmless but unavoidable
/// for pure SPM executables.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register as a regular foreground application *before* the UI is set up.
        // Without this, macOS treats the process as a background/accessory app
        // and never routes keyboard events to its windows.
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bring the app to the foreground.
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Make the first eligible window the key window so it receives keyboard input.
        // This covers initial launch and reactivation (e.g. clicking the Dock icon).
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
