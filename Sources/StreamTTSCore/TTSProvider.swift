import AVFoundation

/// A provider that converts streaming text into streaming PCM audio data.
public protocol TTSProvider: Sendable {
    /// The audio format of the PCM data emitted by this provider.
    /// The pipeline uses this to configure AVAudioConverter.
    var outputFormat: AVAudioFormat { get }

    /// Begins streaming synthesis. Text chunks arrive via the input stream;
    /// PCM audio data chunks are emitted on the returned stream.
    ///
    /// The provider must handle its own authentication and connection lifecycle.
    /// Cancelling the Task that consumes the returned stream should tear down
    /// the underlying connection.
    func stream(text: AsyncStream<String>) -> AsyncThrowingStream<Data, Error>
}
