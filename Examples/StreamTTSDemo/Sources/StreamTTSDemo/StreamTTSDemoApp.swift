import SwiftUI

/// StreamTTS Demo — a minimal macOS app for testing streaming text-to-speech.
@main
struct StreamTTSDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 550, minHeight: 450)
        }
        .defaultSize(width: 600, height: 500)
    }
}
