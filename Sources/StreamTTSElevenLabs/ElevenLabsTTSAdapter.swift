import StreamTTSCore
import AVFoundation
import Foundation

// MARK: - WebSocket connection delegate

/// Bridges `URLSessionWebSocketDelegate` callbacks into Swift Concurrency.
/// Allows callers to `await` the WebSocket open event before sending.
private final class WebSocketOpenDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let openLock = NSLock()
    private var openContinuation: CheckedContinuation<Void, Error>?

    /// Suspends the caller until the WebSocket handshake completes or fails.
    func waitForOpen() async throws {
        try await withCheckedThrowingContinuation { cont in
            openLock.lock()
            openContinuation = cont
            openLock.unlock()
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        openLock.withLock {
            openContinuation?.resume()
            openContinuation = nil
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        openLock.withLock {
            openContinuation?.resume(
                throwing: StreamTTSError.providerConnectionFailed(
                    underlying: URLError(.networkConnectionLost)
                )
            )
            openContinuation = nil
        }
    }
}

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
            let urlString = "wss://api.elevenlabs.io/v1/text-to-speech/\(configuration.voiceId)/stream-input?model_id=\(configuration.modelId)&output_format=\(configuration.outputFormat.rawValue)"
            
            guard let url = URL(string: urlString) else {
                continuation.finish(throwing: StreamTTSError.providerConnectionFailed(underlying: URLError(.badURL)))
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue(configuration.apiKey, forHTTPHeaderField: "xi-api-key")

            // Use a delegate-backed session so we can wait for the WebSocket
            // handshake to complete before sending any messages. Without this,
            // send() races against the TCP/TLS/WS upgrade and throws POSIX 57
            // ("Socket is not connected").
            let delegate = WebSocketOpenDelegate()
            let session = URLSession(
                configuration: .default,
                delegate: delegate,
                delegateQueue: nil
            )
            let webSocketTask = session.webSocketTask(with: request)
            webSocketTask.resume()
            
            let coordinatorTask = Task {
                do {
                    // Wait until the WebSocket handshake is done before sending.
                    try await delegate.waitForOpen()

                    try await withThrowingTaskGroup(of: Void.self) { group in
                        
                        group.addTask {
                            // Send initial configuration message
                            let initialMessage: [String: Any] = [
                                "text": " ",
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
