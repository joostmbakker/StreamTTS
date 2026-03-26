import AVFoundation

public enum StreamTTSError: Error, Sendable {
    case providerConnectionFailed(underlying: Error)
    case authenticationFailed(underlying: Error)
    case audioEngineSetupFailed(underlying: Error)
    case formatConversionFailed(from: AVAudioFormat, to: AVAudioFormat)
    case streamCancelled
    case bufferOverflow(accumulatedBytes: Int)
}
