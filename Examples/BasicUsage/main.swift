import Foundation
import StreamTTSCore
import StreamTTSElevenLabs
import StreamTTSGoogleCloud

// Note: To run this example, you need to create an executable target in your Package.swift
// or copy this into an iOS/macOS app project.

@main
struct StreamTTSExample {
    static func main() async throws {
        print("Starting StreamTTS Example...")
        
        // --- 1. Using ElevenLabs ---
        try await runElevenLabsExample()
        
        // --- 2. Using Google Cloud ---
        // try await runGoogleCloudExample()
        
        print("Finished.")
    }
    
    static func runElevenLabsExample() async throws {
        // Provide your ElevenLabs API Key here
        let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] ?? "YOUR_API_KEY"
        
        // We use the "Rachel" voice ID by default
        let config = ElevenLabsConfiguration(apiKey: apiKey, voiceId: "21m00Tcm4TlvDq8ikWAM")
        let provider = ElevenLabsTTSAdapter(configuration: config)
        
        // Initialize the controller
        let controller = StreamingTTSController(provider: provider)
        
        // Start playback
        try await controller.start()
        
        // Simulate an LLM streaming text back
        let chunks = [
            "Hello there! ",
            "I'm streaming this text directly ",
            "into the ElevenLabs API, ",
            "and playing it back immediately."
        ]
        
        for chunk in chunks {
            print("Yielding: \(chunk)")
            controller.yield(text: chunk)
            try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
        }
        
        // Inform the pipeline that no more text is coming
        controller.finish()
        
        // Wait for the audio to finish playing
        await controller.waitUntilFinished()
    }
    
    static func runGoogleCloudExample() async throws {
        // You'll need to implement GoogleAuthProvider to supply your OAuth token.
        struct DummyAuthProvider: GoogleAuthProvider {
            func accessToken() async throws -> String {
                // Return a real access token retrieved via Google Sign-In or a service account.
                return ProcessInfo.processInfo.environment["GOOGLE_TTS_TOKEN"] ?? "YOUR_OAUTH_TOKEN"
            }
        }
        
        let config = GoogleCloudTTSConfiguration()
        let authProvider = DummyAuthProvider()
        let provider = GoogleCloudTTSAdapter(configuration: config, authProvider: authProvider)
        
        let controller = StreamingTTSController(provider: provider)
        try await controller.start()
        
        let chunks = [
            "This is a demonstration ",
            "of the Google Cloud TTS adapter, ",
            "streaming perfectly with StreamTTS."
        ]
        
        for chunk in chunks {
            controller.yield(text: chunk)
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        
        controller.finish()
        await controller.waitUntilFinished()
    }
}
