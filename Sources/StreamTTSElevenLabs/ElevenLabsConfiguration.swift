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
    
    /// Voice settings controlling synthesis characteristics.
    ///
    /// Defaults match ElevenLabs' recommended baseline values.
    public var voiceSettings: VoiceSettings = .init()
    
    /// Creates a new configuration.
    /// - Parameters:
    ///   - apiKey: The ElevenLabs API key.
    ///   - voiceId: The voice ID to use.
    public init(apiKey: String, voiceId: String) {
        self.apiKey = apiKey
        self.voiceId = voiceId
    }
    
    /// Controls voice synthesis characteristics sent in the BOS (Beginning of Stream) message.
    public struct VoiceSettings: Sendable {
        /// Controls the randomness of the voice. Lower values make the voice more consistent.
        public var stability: Double
        
        /// Controls how closely the AI attempts to replicate the original voice.
        public var similarityBoost: Double
        
        /// Controls the style exaggeration. Higher values increase expressiveness.
        public var style: Double
        
        /// Whether to use speaker boost for enhanced clarity.
        public var useSpeakerBoost: Bool
        
        /// Creates voice settings with the specified parameters.
        /// - Parameters:
        ///   - stability: Voice stability (0.0–1.0). Defaults to `0.5`.
        ///   - similarityBoost: Similarity boost (0.0–1.0). Defaults to `0.8`.
        ///   - style: Style exaggeration (0.0–1.0). Defaults to `0.0`.
        ///   - useSpeakerBoost: Enable speaker boost. Defaults to `true`.
        public init(
            stability: Double = 0.5,
            similarityBoost: Double = 0.8,
            style: Double = 0.0,
            useSpeakerBoost: Bool = true
        ) {
            self.stability = stability
            self.similarityBoost = similarityBoost
            self.style = style
            self.useSpeakerBoost = useSpeakerBoost
        }
    }
}
