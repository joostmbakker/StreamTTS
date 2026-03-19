import AVFoundation

public final class StreamingTTSController: Sendable {
    public init(provider: any TTSProvider) {
    }

    /// Starts streaming synthesis and playback.
    public func start() async throws {
    }

    /// Yields a chunk of text to the provider.
    public func yield(text: String) {
    }

    /// Signals that no more text will be yielded.
    public func finish() {
    }

    /// Immediately stops playback and tears down connections.
    public func cancel() {
    }
}
