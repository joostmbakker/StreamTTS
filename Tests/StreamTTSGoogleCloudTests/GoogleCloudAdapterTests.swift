import XCTest
import AVFoundation
@testable import StreamTTSCore
@testable import StreamTTSGoogleCloud

struct EnvVarAuthProvider: GoogleAuthProvider {
    let token: String
    func accessToken() async throws -> String {
        return token
    }
}

final class GoogleCloudAdapterTests: XCTestCase {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    func testLiveGoogleCloudTTSStreaming() async throws {
        guard let token = ProcessInfo.processInfo.environment["GOOGLE_TTS_ACCESS_TOKEN"] else {
            throw XCTSkip("Skipping live Google Cloud TTS test because GOOGLE_TTS_ACCESS_TOKEN is not set.")
        }
        
        let authProvider = EnvVarAuthProvider(token: token)
        let config = GoogleCloudTTSConfiguration()
        let adapter = GoogleCloudTTSAdapter(configuration: config, authProvider: authProvider)
        
        let textChunks = ["Hello", " world", " from", " Google", " Cloud", " TTS."]
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
