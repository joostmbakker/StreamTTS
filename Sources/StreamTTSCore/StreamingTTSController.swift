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
    ///
    /// - Throws: `StreamTTSError.alreadyStarted` if called more than once,
    ///           or `StreamTTSError.alreadyCancelled` if the controller was cancelled.
    public func start() async throws {
        let stream = try prepareStart()
        
        let audioStream = provider.stream(text: stream)
        try await pipeline.start(stream: audioStream, format: provider.outputFormat)
    }
    
    private func prepareStart() throws -> AsyncStream<String> {
        lock.lock()
        defer { lock.unlock() }
        
        if isCancelled {
            throw StreamTTSError.alreadyCancelled
        }
        if isStarted {
            throw StreamTTSError.alreadyStarted
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
    
    /// Synthesizes and plays back a single string of text.
    ///
    /// This is a convenience wrapper around the manual `start() → yield(text:) → finish()`
    /// lifecycle. It starts the pipeline, sends the entire text as a single chunk, signals
    /// completion, and waits for all audio to finish playing before returning.
    ///
    /// Use this when you have the full text available upfront. For incremental streaming
    /// (e.g., yielding chunks from an LLM response), use `start()`, `yield(text:)`,
    /// `finish()`, and `waitUntilFinished()` instead.
    ///
    /// - Parameter text: The text to synthesize and play.
    /// - Throws: `StreamTTSError.alreadyStarted` if the controller has already been started,
    ///           `StreamTTSError.alreadyCancelled` if the controller was cancelled,
    ///           or any error from the provider or audio pipeline.
    public func speak(_ text: String) async throws {
        try await start()
        yield(text: text)
        finish()
        await waitUntilFinished()
    }
}
