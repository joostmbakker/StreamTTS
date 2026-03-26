import StreamTTSCore
import AVFoundation
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf

/// Configuration for the Google Cloud TTS provider.
public struct GoogleCloudTTSConfiguration: Sendable {
    /// The voice selection parameters.
    public var voice: Voice = .init(languageCode: "en-US", name: "en-US-Neural2-A")
    
    /// The audio encoding format.
    public var audioEncoding: AudioEncoding = .linear16
    
    /// The sample rate in Hertz.
    public var sampleRateHertz: Int = 24000

    /// Voice selection parameters.
    public struct Voice: Sendable {
        /// The language code (e.g., "en-US").
        public var languageCode: String
        
        /// The voice name (e.g., "en-US-Neural2-A").
        public var name: String
        
        /// Creates a new voice selection.
        /// - Parameters:
        ///   - languageCode: The BCP-47 language code.
        ///   - name: The specific voice name.
        public init(languageCode: String, name: String) {
            self.languageCode = languageCode
            self.name = name
        }
    }

    /// Audio encoding options.
    public enum AudioEncoding: Sendable {
        /// 16-bit linear PCM.
        case linear16
    }
    
    /// Creates a default configuration.
    public init() {}
}

/// A `TTSProvider` implementation that uses Google Cloud Text-to-Speech Streaming API.
public struct GoogleCloudTTSAdapter: TTSProvider {
    /// The adapter's configuration.
    public let configuration: GoogleCloudTTSConfiguration
    
    /// The authentication provider for OAuth tokens.
    public let authProvider: any GoogleAuthProvider

    /// The output audio format produced by this adapter.
    public var outputFormat: AVAudioFormat {
        return AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(configuration.sampleRateHertz),
            channels: 1,
            interleaved: false
        )!
    }

    /// Creates a new Google Cloud TTS adapter.
    /// - Parameters:
    ///   - configuration: The configuration to use.
    ///   - authProvider: The authentication provider for OAuth tokens.
    public init(configuration: GoogleCloudTTSConfiguration = .init(), authProvider: any GoogleAuthProvider) {
        self.configuration = configuration
        self.authProvider = authProvider
    }

    /// Begins streaming synthesis via gRPC.
    /// - Parameter text: An async stream of text chunks to synthesize.
    /// - Returns: An async throwing stream of PCM audio data.
    public func stream(text: AsyncStream<String>) -> AsyncThrowingStream<Data, Error> {
        // TODO: Implement using grpc-swift v2 bidirectional streaming API.
        // This will use GRPCClient with HTTP2ClientTransport, inject auth via
        // CallOptions metadata, and bridge the bidi stream to AsyncThrowingStream.
        // See Session 3 for full implementation.
        fatalError("GoogleCloudTTSAdapter.stream(text:) not yet implemented for grpc-swift v2")
    }
}
