import StreamTTSCore
import AVFoundation
import Foundation

// MARK: - Adapter

/// A `TTSProvider` implementation that uses ElevenLabs WebSocket streaming API.
public struct ElevenLabsTTSAdapter: TTSProvider {
    /// The adapter's configuration.
    public let configuration: ElevenLabsConfiguration

    /// The output audio format produced by this adapter.
    public var outputFormat: AVAudioFormat {
        let sampleRate: Double
        switch configuration.outputFormat {
        case .pcm_16000: sampleRate = 16000
        case .pcm_22050: sampleRate = 22050
        case .pcm_24000: sampleRate = 24000
        case .pcm_44100: sampleRate = 44100
        }
        
        return AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
    }

    /// Creates a new ElevenLabs TTS adapter.
    /// - Parameter configuration: The configuration to use.
    public init(configuration: ElevenLabsConfiguration) {
        self.configuration = configuration
    }

    /// Begins streaming synthesis via WebSocket.
    /// - Parameter text: An async stream of text chunks to synthesize.
    /// - Returns: An async throwing stream of PCM audio data.
    public func stream(text: AsyncStream<String>) -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            var components = URLComponents()
            components.scheme = "wss"
            components.host = "api.elevenlabs.io"
            components.path = "/v1/text-to-speech/\(configuration.voiceId)/stream-input"
            components.queryItems = [
                URLQueryItem(name: "model_id", value: configuration.modelId),
                URLQueryItem(name: "output_format", value: configuration.outputFormat.rawValue),
                // Pass the API key as a query parameter so it survives the
                // WebSocket upgrade. URLSessionWebSocketTask may strip custom
                // HTTP headers during the HTTP→WS upgrade handshake.
                URLQueryItem(name: "xi-api-key", value: configuration.apiKey),
            ]
            
            guard let url = components.url else {
                continuation.finish(throwing: StreamTTSError.providerConnectionFailed(underlying: URLError(.badURL)))
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue(configuration.apiKey, forHTTPHeaderField: "xi-api-key")

            // Use a delegate-backed session so we can wait for the WebSocket
            // handshake to complete before sending any messages. Without this,
            // send() races against the TCP/TLS/WS upgrade and throws POSIX 57
            // ("Socket is not connected").
            let connectionDelegate = WebSocketConnectionDelegate()
            let session = URLSession(
                configuration: .default,
                delegate: connectionDelegate,
                delegateQueue: nil
            )
            let webSocketTask = session.webSocketTask(with: request)
            webSocketTask.resume()
            
            let coordinatorTask = Task {
                do {
                    // Wait for WebSocket handshake to complete before sending
                    try await connectionDelegate.waitUntilConnected()
                    
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        
                        group.addTask { [configuration] in
                            // Send initial BOS (Beginning of Stream) message.
                            // The API key is included here in addition to the
                            // HTTP header because URLSessionWebSocketTask may
                            // strip custom headers during the WS upgrade.
                            let initialMessage: [String: Any] = [
                                "text": " ",
                                "xi-api-key": configuration.apiKey,
                                "voice_settings": [
                                    "stability": 0.5,
                                    "similarity_boost": 0.8
                                ]
                            ]
                            
                            let initialData = try JSONSerialization.data(withJSONObject: initialMessage)
                            let initialString = String(data: initialData, encoding: .utf8)!
                            try await webSocketTask.send(.string(initialString))
                            
                            // Send text chunks
                            for await chunk in text {
                                if Task.isCancelled { break }
                                
                                let message: [String: Any] = [
                                    "text": chunk,
                                    "try_trigger_generation": true
                                ]
                                
                                let data = try JSONSerialization.data(withJSONObject: message)
                                let string = String(data: data, encoding: .utf8)!
                                try await webSocketTask.send(.string(string))
                            }
                            
                            // Send end of stream message
                            let endMessage: [String: Any] = ["text": ""]
                            let endData = try JSONSerialization.data(withJSONObject: endMessage)
                            let endString = String(data: endData, encoding: .utf8)!
                            try await webSocketTask.send(.string(endString))
                        }
                        
                        group.addTask {
                            while !Task.isCancelled {
                                let message = try await webSocketTask.receive()
                                switch message {
                                case .string(let text):
                                    guard let data = text.data(using: .utf8),
                                          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                                        continue
                                    }
                                    
                                    if let audioBase64 = json["audio"] as? String,
                                       let audioData = Data(base64Encoded: audioBase64),
                                       !audioData.isEmpty {
                                        continuation.yield(audioData)
                                    }
                                    
                                    if let isFinal = json["isFinal"] as? Bool, isFinal {
                                        return // Break the loop, end the task
                                    }
                                    
                                case .data(let data):
                                    if !data.isEmpty {
                                        continuation.yield(data)
                                    }
                                @unknown default:
                                    break
                                }
                            }
                        }
                        
                        // Wait for both tasks to complete or throw
                        try await group.waitForAll()
                    }
                    
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: StreamTTSError.streamCancelled)
                } catch {
                    if (error as? URLError)?.code == .cancelled {
                        continuation.finish(throwing: StreamTTSError.streamCancelled)
                    } else {
                        continuation.finish(throwing: StreamTTSError.providerConnectionFailed(underlying: error))
                    }
                }
            }
            continuation.onTermination = { @Sendable termination in
                webSocketTask.cancel(with: .normalClosure, reason: nil)
                session.invalidateAndCancel()
                coordinatorTask.cancel()
            }
        }
    }
}

// MARK: - WebSocket Connection Delegate

/// A delegate that signals when the WebSocket handshake completes or fails.
private final class WebSocketConnectionDelegate: NSObject, URLSessionWebSocketDelegate, Sendable {
    private let continuation: AsyncStream<Result<Void, Error>>.Continuation
    private let stream: AsyncStream<Result<Void, Error>>

    override init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Result<Void, Error>.self)
        self.stream = stream
        self.continuation = continuation
        super.init()
    }

    /// Awaits until the WebSocket is open, or throws if it fails.
    func waitUntilConnected() async throws {
        for await result in stream {
            switch result {
            case .success:
                return
            case .failure(let error):
                throw error
            }
        }
        // Stream finished without a signal — connection was never established
        throw URLError(.cannotConnectToHost)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        continuation.yield(.success(()))
        continuation.finish()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        continuation.yield(.failure(URLError(.networkConnectionLost)))
        continuation.finish()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            continuation.yield(.failure(error))
            continuation.finish()
        }
    }
}
