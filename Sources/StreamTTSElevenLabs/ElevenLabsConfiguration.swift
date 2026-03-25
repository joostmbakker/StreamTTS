import Foundation

/// Configuration for the ElevenLabs TTS provider.
public struct ElevenLabsConfiguration: Sendable {
    /// The API key for authenticating with ElevenLabs.
    public var apiKey: String
    
    /// The specific voice ID to use for synthesis.
    public var voiceId: String
    
    /// The model ID to use.
    ///
    /// Defaults to `eleven_flash_v2_5`, ElevenLabs' fastest model (~75 ms latency).
    /// Other WebSocket-compatible options include `eleven_flash_v2`,
    /// `eleven_multilingual_v2`, `eleven_turbo_v2_5`, and `eleven_turbo_v2`.
    ///
    /// > Important: `eleven_v3` does **not** support WebSocket streaming.
    /// > The legacy `eleven_monolingual_v1` model was removed on 2025-12-15.
    public var modelId: String = "eleven_flash_v2_5"
    
    /// The desired output audio format from ElevenLabs.
    ///
    /// Defaults to `.pcm_24000`. Note that `.pcm_44100` requires a Pro-tier
    /// ElevenLabs subscription; lower sample-rate PCM formats are available
    /// on all tiers.
    public var outputFormat: ElevenLabsOutputFormat = .pcm_24000

    /// Supported output formats from ElevenLabs.
    public enum ElevenLabsOutputFormat: String, Sendable {
        case pcm_16000 = "pcm_16000"
        case pcm_22050 = "pcm_22050"
        case pcm_24000 = "pcm_24000"
        case pcm_44100 = "pcm_44100"
    }
    
    /// Creates a new configuration.
    /// - Parameters:
    ///   - apiKey: The ElevenLabs API key.
    ///   - voiceId: The voice ID to use.
    public init(apiKey: String, voiceId: String) {
        self.apiKey = apiKey
        self.voiceId = voiceId
    }
}
