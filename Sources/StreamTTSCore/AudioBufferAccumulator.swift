import Foundation
import AVFoundation

public struct AudioBufferAccumulator {
    private var buffer = Data()
    public let threshold: Int
    public let bytesPerFrame: Int

    public init(threshold: Int = 4096, format: AVAudioFormat) {
        self.threshold = threshold
        let calculatedBytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        // Fallback if mBytesPerFrame is 0 (e.g., for compressed formats, though we expect PCM)
        self.bytesPerFrame = calculatedBytesPerFrame > 0 ? calculatedBytesPerFrame : Int(format.channelCount) * 2 // Assuming 16-bit by default if 0
    }

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
