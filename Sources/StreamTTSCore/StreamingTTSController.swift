import Foundation
import AVFoundation

/// Public API entry point. Coordinates a TTSProvider and a StreamingAudioPipeline.
public final class StreamingTTSController: @unchecked Sendable {
    private let provider: any TTSProvider
    private let pipeline: StreamingAudioPipeline
    
    private let lock = NSLock()
    private var textContinuation: AsyncStream<String>.Continuation?
    private var isStarted = false
    private var isCancelled = false
    
    /// Creates a new controller with the specified TTS provider.
    /// - Parameter provider: The TTS provider to use for synthesis.
    public init(provider: any TTSProvider) {
        self.provider = provider
        self.pipeline = StreamingAudioPipeline()
    }
    
    /// Starts streaming synthesis and playback.
    public func start() async throws {
        let streamSetup = prepareStart()
        guard let stream = streamSetup else {
            return
        }
        
        let audioStream = provider.stream(text: stream)
        try await pipeline.start(stream: audioStream, format: provider.outputFormat)
    }
    
    private func prepareStart() -> AsyncStream<String>? {
        lock.lock()
        defer { lock.unlock() }
        
        if isStarted || isCancelled {
            return nil
        }
        isStarted = true
        
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        self.textContinuation = continuation
        return stream
    }
    
    /// Yields a chunk of text to the provider.
    public func yield(text: String) {
        lock.lock()
        let continuation = textContinuation
        lock.unlock()
        
        continuation?.yield(text)
    }
    
    /// Signals that no more text will be yielded.
    public func finish() {
        lock.lock()
        let continuation = textContinuation
        textContinuation = nil
        lock.unlock()
        
        continuation?.finish()
    }
    
    /// Immediately stops playback and tears down connections.
    public func cancel() {
        lock.lock()
        isCancelled = true
        let continuation = textContinuation
        textContinuation = nil
        lock.unlock()
        
        continuation?.finish()
        
        Task {
            await pipeline.cancel()
        }
    }
    
    /// Waits until all scheduled audio has finished playing.
    public func waitUntilFinished() async {
        await pipeline.waitUntilFinished()
    }
}
