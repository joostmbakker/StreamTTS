import XCTest
import AVFoundation
@testable import StreamTTSCore

final class AudioBufferAccumulatorTests: XCTestCase {
    var format: AVAudioFormat!

    override func setUp() {
        super.setUp()
        // 16-bit, 24kHz, mono = 2 bytes per frame
        format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!
    }

    func testAccumulationUnderThreshold() {
        var accumulator = AudioBufferAccumulator(threshold: 10, format: format)
        let chunks = accumulator.append(Data(repeating: 0, count: 6))
        XCTAssertTrue(chunks.isEmpty)
    }

    func testAccumulationExceedsThreshold() {
        var accumulator = AudioBufferAccumulator(threshold: 10, format: format)
        // 10 bytes threshold, 2 bytes per frame -> effective threshold is 10
        let chunks = accumulator.append(Data(repeating: 0, count: 12))
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].count, 10)
    }

    func testMultipleChunksEmitted() {
        var accumulator = AudioBufferAccumulator(threshold: 10, format: format)
        // 25 bytes appended
        let chunks = accumulator.append(Data(repeating: 0, count: 25))
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].count, 10)
        XCTAssertEqual(chunks[1].count, 10)
    }

    func testFlushEmitsRemainingAlignedData() {
        var accumulator = AudioBufferAccumulator(threshold: 10, format: format)
        _ = accumulator.append(Data(repeating: 0, count: 5)) // 5 bytes
        let finalChunk = accumulator.flush()
        
        // 5 bytes % 2 bytes/frame = 1 byte remainder
        // It should drop 1 byte and emit 4 bytes
        XCTAssertEqual(finalChunk?.count, 4)
    }
    
    func testFlushEmpty() {
        var accumulator = AudioBufferAccumulator(threshold: 10, format: format)
        let finalChunk = accumulator.flush()
        XCTAssertNil(finalChunk)
    }
    
    func testFlushWithLessThanOneFrame() {
        var accumulator = AudioBufferAccumulator(threshold: 10, format: format)
        _ = accumulator.append(Data(repeating: 0, count: 1)) // 1 byte, which is less than 2 bytes/frame
        let finalChunk = accumulator.flush()
        XCTAssertNil(finalChunk)
    }
}
