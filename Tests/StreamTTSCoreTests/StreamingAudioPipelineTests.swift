import XCTest
import AVFoundation
@testable import StreamTTSCore

final class StreamingAudioPipelineTests: XCTestCase {

    func testPipelineLifecycle() async throws {
        // We use MockTTSProvider to generate stream
        let provider = MockTTSProvider(sampleRate: 24000.0)
        
        let config = AudioPipelineConfiguration(
            chunkAccumulationSize: 4096,
            playbackWatermark: 0.1, // Start playback quickly
            maxBufferedDuration: 1.0,
            managesAudioEngine: true
        )
        
        let pipeline = StreamingAudioPipeline(configuration: config)
        
        // Create an AsyncStream of text chunks
        let (textStream, continuation) = AsyncStream<String>.makeStream()
        
        let audioStream = provider.stream(text: textStream)
        
        // Start the pipeline
        try await pipeline.start(stream: audioStream, format: provider.outputFormat)
        
        // Yield some text
        continuation.yield("Hello ")
        continuation.yield("World")
        continuation.finish()
        
        // Wait for pipeline to finish playing everything
        await pipeline.waitUntilFinished()
        
        // If we reach here without hanging or crashing, the test succeeds
        XCTAssertTrue(true)
    }
    
    func testPipelineCancellation() async throws {
        let provider = MockTTSProvider()
        let pipeline = StreamingAudioPipeline(
            configuration: AudioPipelineConfiguration(
                maxBufferedDuration: 5.0
            )
        )
        
        let (textStream, continuation) = AsyncStream<String>.makeStream()
        let audioStream = provider.stream(text: textStream)
        
        try await pipeline.start(stream: audioStream, format: provider.outputFormat)
        
        continuation.yield("Hello")
        
        // Allow some time for processing
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Cancel the pipeline before finishing
        await pipeline.cancel()
        continuation.finish()
        
        XCTAssertTrue(true)
    }
}
