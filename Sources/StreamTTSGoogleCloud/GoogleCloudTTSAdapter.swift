import StreamTTSCore
import AVFoundation

public struct GoogleCloudTTSConfiguration: Sendable {
    public var voice: Voice = .init(languageCode: "en-US", name: "en-US-Neural2-A")
    public var audioEncoding: AudioEncoding = .linear16
    public var sampleRateHertz: Int = 24000

    public struct Voice: Sendable {
        public var languageCode: String
        public var name: String
        
        public init(languageCode: String, name: String) {
            self.languageCode = languageCode
            self.name = name
        }
    }

    public enum AudioEncoding: Sendable {
        case linear16
    }
    
    public init() {}
}

public struct GoogleCloudTTSAdapter: TTSProvider {
    public var outputFormat: AVAudioFormat {
        return AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
    }

    public init(configuration: GoogleCloudTTSConfiguration = .init(), authProvider: any GoogleAuthProvider) {
    }

    public func stream(text: AsyncStream<String>) -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
