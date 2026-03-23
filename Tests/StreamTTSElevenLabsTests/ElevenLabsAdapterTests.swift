import XCTest
import AVFoundation
@testable import StreamTTSCore
@testable import StreamTTSElevenLabs

final class ElevenLabsAdapterTests: XCTestCase {
    func testLiveElevenLabsTTSStreaming() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] else {
            throw XCTSkip("Skipping live ElevenLabs test because ELEVENLABS_API_KEY is not set.")
        }
        
        let config = ElevenLabsConfiguration(apiKey: apiKey, voiceId: "21m00Tcm4TlvDq8ikWAM")
        let adapter = ElevenLabsTTSAdapter(configuration: config)
        
        let textChunks = ["Hello,", " this", " is", " a", " test", " of", " Eleven", " Labs", " streaming."]
        let (inputStream, continuation) = AsyncStream.makeStream(of: String.self)
        
        let audioStream = adapter.stream(text: inputStream)
        
        Task {
            for chunk in textChunks {
                continuation.yield(chunk)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            continuation.finish()
        }
        
        var receivedData = Data()
        var chunkCount = 0
        
        for try await chunk in audioStream {
            receivedData.append(chunk)
            chunkCount += 1
        }
        
        XCTAssertGreaterThan(chunkCount, 0, "Should receive at least one audio chunk")
        XCTAssertGreaterThan(receivedData.count, 0, "Should receive some audio bytes")
    }
}
