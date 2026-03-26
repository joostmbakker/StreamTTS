import StreamTTSCore
import AVFoundation
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf

/// Configuration for the Google Cloud TTS provider.
public struct GoogleCloudTTSConfiguration: Sendable {
    /// The voice selection parameters.
    ///
    /// The default uses a Chirp 3: HD voice, which is required for the
    /// `StreamingSynthesize` RPC.
    public var voice: Voice = .init(languageCode: "en-US", name: "en-US-Chirp3-HD-Achernar")

    /// The audio encoding format.
    public var audioEncoding: AudioEncoding = .linear16

    /// The sample rate in Hertz.
    public var sampleRateHertz: Int = 24000

    /// Optional Google Cloud quota project ID.
    ///
    /// Required when authenticating with user credentials (e.g., `gcloud auth
    /// print-access-token`). Service account credentials typically don't need this.
    /// Sets the `x-goog-user-project` metadata header on each RPC.
    public var quotaProjectID: String?

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

/// A `TTSProvider` implementation that uses Google Cloud Text-to-Speech Streaming API
/// via grpc-swift v2.
///
/// Uses `HTTP2ClientTransport.TransportServices` (Network.framework) so the adapter
/// works on both iOS and macOS without platform-conditional compilation.
///
/// - Important: Requires macOS 15.0+ / iOS 18.0+ at runtime due to grpc-swift v2
///   transport and generated client availability requirements.
@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
public struct GoogleCloudTTSAdapter: TTSProvider {
    /// The adapter's configuration.
    public let configuration: GoogleCloudTTSConfiguration

    /// The authentication provider for OAuth tokens.
    public let authProvider: any GoogleAuthProvider

    /// The output audio format produced by this adapter.
    public var outputFormat: AVAudioFormat {
        AVAudioFormat(
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

    /// Begins streaming synthesis via gRPC bidirectional stream.
    ///
    /// Opens a `StreamingSynthesize` RPC, sends the configuration as the first
    /// message, then forwards each text chunk from the input stream. Audio data
    /// chunks are yielded on the returned stream as they arrive from the server.
    ///
    /// Cancelling the `Task` that consumes the returned stream tears down the
    /// gRPC connection automatically.
    ///
    /// - Parameter text: An async stream of text chunks to synthesize.
    /// - Returns: An async throwing stream of PCM audio data.
    public func stream(text: AsyncStream<String>) -> AsyncThrowingStream<Data, Error> {
        let config = self.configuration
        let auth = self.authProvider

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let token = try await auth.accessToken()

                    var metadata: Metadata = ["authorization": "Bearer \(token)"]
                    if let quotaProject = config.quotaProjectID {
                        metadata.addString(quotaProject, forKey: "x-goog-user-project")
                    }

                    let transport = try HTTP2ClientTransport.TransportServices(
                        target: .dns(host: "texttospeech.googleapis.com", port: 443),
                        transportSecurity: .tls
                    )

                    try await withGRPCClient(transport: transport) { grpcClient in
                        let ttsClient = Google_Cloud_Texttospeech_V1_TextToSpeech.Client(
                            wrapping: grpcClient
                        )

                        let request = StreamingClientRequest(
                            of: Google_Cloud_Texttospeech_V1_StreamingSynthesizeRequest.self,
                            metadata: metadata
                        ) { writer in
                            // First message: streaming config (voice + audio settings).
                            var configMsg = Google_Cloud_Texttospeech_V1_StreamingSynthesizeRequest()
                            var streamingConfig = Google_Cloud_Texttospeech_V1_StreamingSynthesizeConfig()

                            var voice = Google_Cloud_Texttospeech_V1_VoiceSelectionParams()
                            voice.languageCode = config.voice.languageCode
                            voice.name = config.voice.name
                            streamingConfig.voice = voice

                            var audioConfig = Google_Cloud_Texttospeech_V1_StreamingAudioConfig()
                            // Streaming API requires .pcm (headerless), not .linear16 (WAV-wrapped).
                            audioConfig.audioEncoding = .pcm
                            audioConfig.sampleRateHertz = Int32(config.sampleRateHertz)
                            streamingConfig.streamingAudioConfig = audioConfig

                            configMsg.streamingConfig = streamingConfig
                            try await writer.write(configMsg)

                            // Subsequent messages: one per text chunk.
                            for await chunk in text {
                                var inputMsg = Google_Cloud_Texttospeech_V1_StreamingSynthesizeRequest()
                                var input = Google_Cloud_Texttospeech_V1_StreamingSynthesisInput()
                                input.text = chunk
                                inputMsg.input = input
                                try await writer.write(inputMsg)
                            }
                            // Returning closes the client half of the stream.
                        }

                        try await ttsClient.streamingSynthesize(request: request) { response in
                            switch response.accepted {
                            case .success(let contents):
                                for try await part in contents.bodyParts {
                                    switch part {
                                    case .message(let message):
                                        let audio = message.audioContent
                                        if !audio.isEmpty {
                                            continuation.yield(audio)
                                        }
                                    case .trailingMetadata:
                                        break
                                    }
                                }
                            case .failure(let error):
                                throw StreamTTSError.providerConnectionFailed(underlying: error)
                            }
                        }
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: StreamTTSError.streamCancelled)
                } catch let error as StreamTTSError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: StreamTTSError.providerConnectionFailed(underlying: error))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
