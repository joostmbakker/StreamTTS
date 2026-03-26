import Foundation
import AVFoundation

/// Efficiently accumulates incoming PCM byte chunks into contiguous buffers suitable for AVAudioConverter.
public struct AudioBufferAccumulator {
    private var buffer = Data()
    
    /// The size in bytes at which the accumulator will emit a completed chunk.
    public let threshold: Int
    
    /// The number of bytes per audio frame.
    public let bytesPerFrame: Int

    /// Creates a new buffer accumulator.
    /// - Parameters:
    ///   - threshold: The size in bytes to accumulate before emitting.
    ///   - format: The audio format of the incoming PCM data.
    public init(threshold: Int = 4096, format: AVAudioFormat) {
        self.threshold = threshold
        let calculatedBytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        // Fallback if mBytesPerFrame is 0 (e.g., for compressed formats, though we expect PCM)
        self.bytesPerFrame = calculatedBytesPerFrame > 0 ? calculatedBytesPerFrame : Int(format.channelCount) * 2 // Assuming 16-bit by default if 0
    }

    /// Appends incoming PCM data and returns any accumulated chunks that have reached the threshold.
    /// - Parameter data: The new PCM data to append.
    /// - Returns: An array of completed data chunks.
    public mutating func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var result: [Data] = []

        // Extract chunks of `threshold` size, but ensuring it's a multiple of bytesPerFrame
        let effectiveThreshold = (threshold / bytesPerFrame) * bytesPerFrame
        guard effectiveThreshold > 0 else { return [] }

        while buffer.count >= effectiveThreshold {
            let chunk = buffer.prefix(effectiveThreshold)
            result.append(Data(chunk))
            buffer.removeFirst(effectiveThreshold)
        }

        return result
    }

    /// Flushes any remaining accumulated data, dropping partial frames if necessary.
    /// - Returns: The final chunk of data, if any valid bytes exist.
    public mutating func flush() -> Data? {
        guard !buffer.isEmpty else { return nil }
        
        // Ensure what's left is aligned to bytesPerFrame, drop any partial frames
        let remainder = buffer.count % bytesPerFrame
        let validBytes = buffer.count - remainder
        
        guard validBytes > 0 else {
            buffer.removeAll()
            return nil
        }
        
        let finalData = Data(buffer.prefix(validBytes))
        buffer.removeAll()
        return finalData
    }
}
