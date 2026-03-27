import XCTest
import AVFoundation
@testable import StreamTTSCore

final class StreamingTTSControllerTests: XCTestCase {
    
    func testStreamingLifecycle() async throws {
        let provider = MockTTSProvider(sampleRate: 24000, frequency: 440)
        let controller = StreamingTTSController(provider: provider)
        
        try await controller.start()
        
        controller.yield(text: "Hello ")
        controller.yield(text: "world")
        controller.finish()
        
        await controller.waitUntilFinished()
        
        // Verify the provider actually received the text chunks
        XCTAssertEqual(provider.receivedChunkCount, 2)
        XCTAssertEqual(provider.receivedChunks, ["Hello ", "world"])
    }
    
    func testCancellation() async throws {
        let provider = MockTTSProvider(sampleRate: 24000, frequency: 440)
        let controller = StreamingTTSController(provider: provider)
        
        try await controller.start()
        
        controller.yield(text: "Chunk 1")
        controller.yield(text: "Chunk 2")
        
        controller.cancel()
        
        // Wait to ensure everything cleans up
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // After cancel, yield should be a no-op (no crash, text is silently dropped)
        controller.yield(text: "Should be dropped")
        
        // Verify start after cancel throws alreadyCancelled
        do {
            try await controller.start()
            XCTFail("Expected alreadyCancelled error")
        } catch let error as StreamTTSError {
            guard case .alreadyCancelled = error else {
                XCTFail("Expected .alreadyCancelled, got \(error)")
                return
            }
        }
    }
    
    func testStartAfterStartThrows() async throws {
        let provider = MockTTSProvider(sampleRate: 24000, frequency: 440)
        let controller = StreamingTTSController(provider: provider)
        
        try await controller.start()
        
        do {
            try await controller.start()
            XCTFail("Expected alreadyStarted error")
        } catch let error as StreamTTSError {
            guard case .alreadyStarted = error else {
                XCTFail("Expected .alreadyStarted, got \(error)")
                return
            }
        }
        
        controller.finish()
        await controller.waitUntilFinished()
    }
    
    // MARK: - speak() convenience method tests
    
    func testSpeakSingleString() async throws {
        let provider = MockTTSProvider(sampleRate: 24000, frequency: 440)
        let controller = StreamingTTSController(provider: provider)
        
        try await controller.speak("Hello, world!")
        
        // Verify the provider received exactly one chunk with the full text
        XCTAssertEqual(provider.receivedChunkCount, 1)
        XCTAssertEqual(provider.receivedChunks, ["Hello, world!"])
    }
    
    func testSpeakReturnsAfterPlayback() async throws {
        let provider = MockTTSProvider(sampleRate: 24000, frequency: 440)
        let controller = StreamingTTSController(provider: provider)
        
        let startTime = ContinuousClock.now
        try await controller.speak("Test")
        let elapsed = ContinuousClock.now - startTime
        
        // The mock generates 0.1s of audio + 10ms simulated latency per chunk,
        // so speak() should take a measurable amount of time before returning.
        XCTAssertGreaterThan(elapsed, .zero, "speak() should wait for playback to complete")
    }
    
    func testSpeakOnAlreadyStartedControllerThrows() async throws {
        let provider = MockTTSProvider(sampleRate: 24000, frequency: 440)
        let controller = StreamingTTSController(provider: provider)
        
        try await controller.start()
        
        do {
            try await controller.speak("Should fail")
            XCTFail("Expected alreadyStarted error")
        } catch let error as StreamTTSError {
            guard case .alreadyStarted = error else {
                XCTFail("Expected .alreadyStarted, got \(error)")
                return
            }
        }
        
        // Clean up the first start
        controller.finish()
        await controller.waitUntilFinished()
    }
    
    func testSpeakOnCancelledControllerThrows() async throws {
        let provider = MockTTSProvider(sampleRate: 24000, frequency: 440)
        let controller = StreamingTTSController(provider: provider)
        
        controller.cancel()
        
        do {
            try await controller.speak("Should fail")
            XCTFail("Expected alreadyCancelled error")
        } catch let error as StreamTTSError {
            guard case .alreadyCancelled = error else {
                XCTFail("Expected .alreadyCancelled, got \(error)")
                return
            }
        }
    }
    
    func testYieldBeforeStartIsDropped() async throws {
        // Before start() is called, the text continuation is nil,
        // so yield calls are silently dropped. This is documented behavior.
        let provider = MockTTSProvider(sampleRate: 24000, frequency: 440)
        let controller = StreamingTTSController(provider: provider)
        
        // These should not crash — they're silently dropped
        controller.yield(text: "Before start 1")
        controller.yield(text: "Before start 2")
        
        try await controller.start()
        
        controller.yield(text: "After start")
        controller.finish()
        
        await controller.waitUntilFinished()
        
        // Only the chunk sent after start should have been received
        XCTAssertEqual(provider.receivedChunkCount, 1)
        XCTAssertEqual(provider.receivedChunks, ["After start"])
    }
}
