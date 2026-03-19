import Foundation

public struct ElevenLabsConfiguration: Sendable {
    public var apiKey: String
    public var voiceId: String
    public var modelId: String = "eleven_monolingual_v1"
    public var outputFormat: ElevenLabsOutputFormat = .pcm_44100

    public enum ElevenLabsOutputFormat: String, Sendable {
        case pcm_16000 = "pcm_16000"
        case pcm_22050 = "pcm_22050"
        case pcm_24000 = "pcm_24000"
        case pcm_44100 = "pcm_44100"
    }
    
    public init(apiKey: String, voiceId: String) {
        self.apiKey = apiKey
        self.voiceId = voiceId
    }
}
