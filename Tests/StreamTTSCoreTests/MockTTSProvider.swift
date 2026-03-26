import Foundation
import AVFoundation
@testable import StreamTTSCore

public final class MockTTSProvider: TTSProvider, @unchecked Sendable {
    public let sampleRate: Double
    public let frequency: Double
    
    // Tracking state (protected by lock for thread safety)
    private let lock = NSLock()
    private var _receivedChunks: [String] = []
    
    /// The text chunks received by this provider during streaming.
    public var receivedChunks: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _receivedChunks
    }
    
    /// The number of text chunks received.
    public var receivedChunkCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _receivedChunks.count
    }

    public init(sampleRate: Double = 24000.0, frequency: Double = 440.0) {
        self.sampleRate = sampleRate
        self.frequency = frequency
    }
    
    public var outputFormat: AVAudioFormat {
        return AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        )!
    }

    public func stream(text: AsyncStream<String>) -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                var phase: Double = 0.0
                let sampleRate = self?.sampleRate ?? 24000.0
                let frequency = self?.frequency ?? 440.0
                let phaseIncrement = (2.0 * .pi * frequency) / sampleRate
                
                for await chunk in text {
                    self?.trackChunk(chunk)
                    
                    // Generate 0.1s of audio per text chunk
                    let frames = Int(sampleRate * 0.1)
                    var pcmData = Data()
                    pcmData.reserveCapacity(frames * 2) // Int16 = 2 bytes
                    
                    for _ in 0..<frames {
                        let sample = sin(phase)
                        let intSample = Int16(sample * 32767.0)
                        
                        withUnsafeBytes(of: intSample.littleEndian) { buffer in
                            pcmData.append(contentsOf: buffer)
                        }
                        
                        phase += phaseIncrement
                        if phase >= 2.0 * .pi {
                            phase -= 2.0 * .pi
                        }
                    }
                    
                    continuation.yield(pcmData)
                    
                    // Small delay to simulate network latency
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                continuation.finish()
            }
        }
    }
    
    private func trackChunk(_ chunk: String) {
        lock.lock()
        _receivedChunks.append(chunk)
        lock.unlock()
    }
}
