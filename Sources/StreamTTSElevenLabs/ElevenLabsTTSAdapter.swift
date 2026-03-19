import StreamTTSCore
import AVFoundation

public struct ElevenLabsTTSAdapter: TTSProvider {
    public var outputFormat: AVAudioFormat {
        return AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    }

    public init(configuration: ElevenLabsConfiguration) {
    }

    public func stream(text: AsyncStream<String>) -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
