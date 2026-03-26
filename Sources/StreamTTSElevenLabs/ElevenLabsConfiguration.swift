import Foundation

/// Configuration for the ElevenLabs TTS provider.
public struct ElevenLabsConfiguration: Sendable {
    /// The API key for authenticating with ElevenLabs.
    public var apiKey: String
    
    /// The specific voice ID to use for synthesis.
    public var voiceId: String
    
    /// The model ID to use (e.g., "eleven_monolingual_v1").
    public var modelId: String = "eleven_monolingual_v1"
    
    /// The desired output audio format from ElevenLabs.
    public var outputFormat: ElevenLabsOutputFormat = .pcm_44100

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
