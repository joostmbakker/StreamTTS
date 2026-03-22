import StreamTTSCore
import AVFoundation
import Foundation
import GRPC
import NIO
import NIOSSL

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
    public let configuration: GoogleCloudTTSConfiguration
    public let authProvider: any GoogleAuthProvider

    public var outputFormat: AVAudioFormat {
        return AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(configuration.sampleRateHertz),
            channels: 1,
            interleaved: false
        )!
    }

    public init(configuration: GoogleCloudTTSConfiguration = .init(), authProvider: any GoogleAuthProvider) {
        self.configuration = configuration
        self.authProvider = authProvider
    }

    public func stream(text: AsyncStream<String>) -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
                var channel: GRPCChannel?
                
                do {
                    channel = try GRPCChannelPool.with(
                        target: .host("texttospeech.googleapis.com", port: 443),
                        transportSecurity: .tls(.makeClientConfigurationBackedByNIOSSL()),
                        eventLoopGroup: group
                    )
                    
                    guard let channel = channel else {
                        throw StreamTTSError.providerConnectionFailed(underlying: NSError(domain: "GoogleCloudTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create gRPC channel."]))
                    }
                    
                    let client = Google_Cloud_Texttospeech_V1_TextToSpeechAsyncClient(channel: channel)
                    
                    let token = try await authProvider.accessToken()
                    var callOptions = CallOptions()
                    callOptions.customMetadata.add(name: "authorization", value: "Bearer \(token)")
                    
                    let call = client.makeStreamingSynthesizeCall(callOptions: callOptions)
                    
                    // 1. Send configuration
                    var configReq = Google_Cloud_Texttospeech_V1_StreamingSynthesizeRequest()
                    var config = Google_Cloud_Texttospeech_V1_StreamingSynthesizeConfig()
                    var voice = Google_Cloud_Texttospeech_V1_VoiceSelectionParams()
                    voice.name = configuration.voice.name
                    voice.languageCode = configuration.voice.languageCode
                    config.voice = voice
                    
                    var streamingAudioConfig = Google_Cloud_Texttospeech_V1_StreamingAudioConfig()
                    switch configuration.audioEncoding {
                    case .linear16:
                        streamingAudioConfig.audioEncoding = .linear16
                    }
                    streamingAudioConfig.sampleRateHertz = Int32(configuration.sampleRateHertz)
                    config.streamingAudioConfig = streamingAudioConfig
                    
                    configReq.streamingConfig = config
                    
                    try await call.requestStream.send(configReq)
                    
                    // Start sending and receiving tasks
                    try await withThrowingTaskGroup(of: Void.self) { tg in
                        tg.addTask {
                            for try await response in call.responseStream {
                                if !response.audioContent.isEmpty {
                                    continuation.yield(response.audioContent)
                                }
                            }
                        }
                        
                        tg.addTask {
                            for await chunk in text {
                                if Task.isCancelled { break }
                                var inputReq = Google_Cloud_Texttospeech_V1_StreamingSynthesizeRequest()
                                var input = Google_Cloud_Texttospeech_V1_StreamingSynthesisInput()
                                input.text = chunk
                                inputReq.input = input
                                try await call.requestStream.send(inputReq)
                            }
                            
                            call.requestStream.finish()
                        }
                        
                        try await tg.waitForAll()
                    }
                    
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: StreamTTSError.streamCancelled)
                } catch {
                    continuation.finish(throwing: StreamTTSError.providerConnectionFailed(underlying: error))
                }
                
                if let channel = channel {
                    try? await channel.close().get()
                }
                try? await group.shutdownGracefully()
            }
            
            continuation.onTermination = { @Sendable termination in
                if case .cancelled = termination {
                    task.cancel()
                }
            }
        }
    }
}
