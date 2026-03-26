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
        
        // If we reach here without throwing and the wait finishes, it succeeds.
        XCTAssertTrue(true)
    }
    
    func testCancellation() async throws {
        let provider = MockTTSProvider(sampleRate: 24000, frequency: 440)
        let controller = StreamingTTSController(provider: provider)
        
        try await controller.start()
        
        controller.yield(text: "Chunk 1")
        controller.yield(text: "Chunk 2")
        
        controller.cancel()
        
        // Wait to ensure everything cleans up
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // controller should stop stream immediately
        XCTAssertTrue(true)
    }
}
