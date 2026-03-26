import AVFoundation

/// Errors that can occur during streaming TTS synthesis and playback.
public enum StreamTTSError: Error, Sendable {
    /// Failed to connect to the TTS provider.
    case providerConnectionFailed(underlying: Error)
    
    /// Authentication with the TTS provider failed.
    case authenticationFailed(underlying: Error)
    
    /// Failed to setup or start the underlying AVAudioEngine.
    case audioEngineSetupFailed(underlying: Error)
    
    /// Failed to convert the audio format from the provider to the engine's output format.
    case formatConversionFailed(from: AVAudioFormat, to: AVAudioFormat)
    
    /// The stream was cancelled before completing.
    case streamCancelled
    
    /// An internal buffer overflow occurred.
    case bufferOverflow(accumulatedBytes: Int)
}
