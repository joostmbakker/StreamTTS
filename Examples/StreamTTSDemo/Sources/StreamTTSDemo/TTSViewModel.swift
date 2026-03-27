import SwiftUI
import StreamTTSCore
import StreamTTSElevenLabs
import StreamTTSGoogleCloud

/// Which TTS provider to use.
enum ProviderType: String, CaseIterable, Identifiable {
    case elevenLabs = "ElevenLabs"
    case googleCloud = "Google Cloud"

    var id: String { rawValue }
}

/// Playback lifecycle state shown in the UI.
enum PlaybackStatus: Equatable {
    case ready
    case connecting
    case streaming
    case playing
    case finished
    case error(String)
}

/// All business logic for the demo app.
///
/// Uses `@Observable` (macOS 14+) for a clean, modern integration with SwiftUI.
/// Provider credentials are persisted via `@AppStorage` where appropriate.
@MainActor
@Observable
final class TTSViewModel {
    // MARK: - Provider selection

    var selectedProvider: ProviderType = .elevenLabs

    // MARK: - ElevenLabs settings

    @ObservationIgnored
    @AppStorage("elevenLabsAPIKey") var elevenLabsAPIKey: String = ""

    @ObservationIgnored
    @AppStorage("elevenLabsVoiceID") var elevenLabsVoiceID: String = "21m00Tcm4TlvDq8ikWAM"
    
    @ObservationIgnored
    @AppStorage("elevenLabsModelID") var elevenLabsModelID: String = "eleven_flash_v2_5"

    // MARK: - Google Cloud settings (tokens are short-lived, not persisted)

    var googleAccessToken: String = ""
    var googleVoiceName: String = "en-US-Chirp3-HD-Achernar"
    
    var googleLanguageCode: String {
        // Extract language code from voice name (e.g. "en-US" from "en-US-Chirp3-HD-Achernar")
        let components = googleVoiceName.split(separator: "-")
        if components.count >= 2 {
            return "\(components[0])-\(components[1])"
        }
        return "en-US"
    }
    
    @ObservationIgnored
    @AppStorage("googleProjectID") var googleProjectID: String = ""

    // MARK: - Playback state

    var inputText: String = "Hello! This is a test of the StreamTTS library. Each sentence is streamed separately to simulate real-time LLM output. The audio should start playing before all text has been sent."
    var status: PlaybackStatus = .ready

    var isPlaying: Bool {
        switch status {
        case .connecting, .streaming, .playing:
            return true
        default:
            return false
        }
    }

    /// Whether the Speak button should be enabled.
    var canSpeak: Bool {
        if isPlaying { return false }
        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        switch selectedProvider {
        case .elevenLabs:
            return !elevenLabsAPIKey.isEmpty && !elevenLabsVoiceID.isEmpty
        case .googleCloud:
            return !googleAccessToken.isEmpty && !googleProjectID.isEmpty
        }
    }

    // MARK: - Private state

    private var playbackTask: Task<Void, Never>?
    private var controller: StreamingTTSController?

    // MARK: - Actions

    /// Creates the appropriate provider, starts the pipeline, and streams text
    /// in sentence-sized chunks with simulated delays.
    func speak() {
        let text = inputText
        playbackTask = Task {
            do {
                status = .connecting

                let provider = try createProvider()
                let ctrl = StreamingTTSController(provider: provider)
                self.controller = ctrl

                try await ctrl.start()
                status = .streaming

                // Simulate LLM-style streaming: yield one sentence at a time.
                let sentences = text.split(separator: ".", omittingEmptySubsequences: true)
                for sentence in sentences {
                    if Task.isCancelled { break }
                    ctrl.yield(text: String(sentence).trimmingCharacters(in: .whitespaces) + ". ")
                    try await Task.sleep(for: .milliseconds(200))
                }

                ctrl.finish()
                status = .playing

                await ctrl.waitUntilFinished()
                if !Task.isCancelled {
                    status = .finished
                }
            } catch is CancellationError {
                status = .ready
            } catch {
                status = .error(error.localizedDescription)
            }

            self.controller = nil
        }
    }

    /// Immediately cancels playback and tears down the connection.
    func stop() {
        controller?.cancel()
        controller = nil
        playbackTask?.cancel()
        playbackTask = nil
        status = .ready
    }

    // MARK: - Provider factory

    @available(macOS 15.0, *)
    private func makeGoogleProvider() throws -> any TTSProvider {
        guard !googleAccessToken.isEmpty else {
            throw ValidationError.missingCredentials("Google access token is required.")
        }
        guard !googleProjectID.isEmpty else {
            throw ValidationError.missingCredentials("Google Project ID is required.")
        }
        var config = GoogleCloudTTSConfiguration()
        config.voice = .init(languageCode: googleLanguageCode, name: googleVoiceName)
        config.quotaProjectID = googleProjectID
        let auth = PastedTokenAuthProvider(token: googleAccessToken)
        return GoogleCloudTTSAdapter(configuration: config, authProvider: auth)
    }

    private func createProvider() throws -> any TTSProvider {
        switch selectedProvider {
        case .elevenLabs:
            guard !elevenLabsAPIKey.isEmpty else {
                throw ValidationError.missingCredentials("ElevenLabs API key is required.")
            }
            var config = ElevenLabsConfiguration(
                apiKey: elevenLabsAPIKey,
                voiceId: elevenLabsVoiceID
            )
            config.modelId = elevenLabsModelID
            return ElevenLabsTTSAdapter(configuration: config)

        case .googleCloud:
            guard #available(macOS 15.0, *) else {
                throw ValidationError.unsupportedPlatform(
                    "Google Cloud TTS requires macOS 15.0 or later."
                )
            }
            return try makeGoogleProvider()
        }
    }
}

/// Validation errors surfaced to the UI before attempting a network call.
enum ValidationError: LocalizedError {
    case missingCredentials(String)
    case unsupportedPlatform(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials(let message): return message
        case .unsupportedPlatform(let message): return message
        }
    }
}
