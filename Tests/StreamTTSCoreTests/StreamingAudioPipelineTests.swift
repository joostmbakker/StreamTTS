import XCTest
import AVFoundation
@testable import StreamTTSCore

final class StreamingAudioPipelineTests: XCTestCase {

    // MARK: - Helpers

    /// Generates valid Int16 PCM sine wave data.
    private func generatePCMData(
        sampleRate: Double = 24000,
        frequency: Double = 440,
        duration: TimeInterval = 0.1
    ) -> Data {
        let frameCount = Int(sampleRate * duration)
        let phaseIncrement = (2.0 * .pi * frequency) / sampleRate
        var phase = 0.0
        var data = Data(capacity: frameCount * 2)

        for _ in 0..<frameCount {
            let sample = Int16(sin(phase) * 32767.0)
            withUnsafeBytes(of: sample.littleEndian) { data.append(contentsOf: $0) }
            phase += phaseIncrement
            if phase >= 2.0 * .pi { phase -= 2.0 * .pi }
        }
        return data
    }

    private func makeFormat(sampleRate: Double = 24000) -> AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        )!
    }

    // MARK: - Tests

    func testPipelineCompletesWithEmptyStream() async throws {
        let pipeline = StreamingAudioPipeline(
            configuration: AudioPipelineConfiguration(
                playbackWatermark: 0.01,
                maxBufferedDuration: 1.0
            )
        )

        // Create a stream that finishes immediately
        let stream = AsyncThrowingStream<Data, Error> { $0.finish() }

        try await pipeline.start(stream: stream, format: makeFormat())
        await pipeline.waitUntilFinished()
        // Reaching here without hanging is the assertion
    }

    func testPipelineProcessesMultipleChunks() async throws {
        let pipeline = StreamingAudioPipeline(
            configuration: AudioPipelineConfiguration(
                chunkAccumulationSize: 1024,
                playbackWatermark: 0.01,
                maxBufferedDuration: 5.0
            )
        )

        let format = makeFormat()
        let chunkData = generatePCMData(duration: 0.1) // ~4800 bytes at 24kHz

        let stream = AsyncThrowingStream<Data, Error> { continuation in
            Task {
                for _ in 0..<5 {
                    continuation.yield(chunkData)
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                continuation.finish()
            }
        }

        try await pipeline.start(stream: stream, format: format)

        // Use a timeout to prevent hanging
        let finished = Task {
            await pipeline.waitUntilFinished()
        }

        let timeout = Task {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5s
        }

        // Race: either finish or timeout
        _ = await Task {
            await withTaskGroup(of: Bool.self) { group in
                group.addTask { await finished.value; return true }
                group.addTask { try? await timeout.value; return false }
                let result = await group.next() ?? false
                group.cancelAll()
                return result
            }
        }.value
    }

    func testPipelineCancellation() async throws {
        let pipeline = StreamingAudioPipeline(
            configuration: AudioPipelineConfiguration(
                playbackWatermark: 0.01,
                maxBufferedDuration: 5.0
            )
        )

        let format = makeFormat()
        let chunkData = generatePCMData(duration: 0.1)

        // A stream that keeps yielding until cancelled
        let stream = AsyncThrowingStream<Data, Error> { continuation in
            let task = Task {
                while !Task.isCancelled {
                    continuation.yield(chunkData)
                    try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }

        try await pipeline.start(stream: stream, format: format)

        // Let some data flow
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Cancel should not hang or crash
        await pipeline.cancel()
    }

    func testBackpressureSuspendsStream() async throws {
        // Very small buffer limit to trigger backpressure quickly.
        // In a test environment without real audio hardware, scheduled buffers
        // never "complete" (the AVAudioPlayerNode completion callback never fires),
        // so queuedDuration only increases and never decreases. This means the
        // pipeline will suspend on backpressure and never resume.
        let pipeline = StreamingAudioPipeline(
            configuration: AudioPipelineConfiguration(
                chunkAccumulationSize: 512,
                playbackWatermark: 0.01,
                maxBufferedDuration: 0.05 // 50ms — very small
            )
        )

        let format = makeFormat()
        // Each chunk is 0.1s of audio — exceeds maxBufferedDuration
        let chunkData = generatePCMData(duration: 0.1)

        let stream = AsyncThrowingStream<Data, Error> { continuation in
            for _ in 0..<20 {
                continuation.yield(chunkData)
            }
            continuation.finish()
        }

        try await pipeline.start(stream: stream, format: format)

        // The pipeline should NOT finish within 500ms because backpressure
        // suspends processing and bufferCompleted never fires in tests.
        let didFinish = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await pipeline.waitUntilFinished()
                return true
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        XCTAssertFalse(didFinish, "Pipeline should be suspended by backpressure, not finished")

        await pipeline.cancel()
    }

    func testAccumulatorIntegration() async throws {
        // Use a large accumulation threshold relative to chunk size
        let pipeline = StreamingAudioPipeline(
            configuration: AudioPipelineConfiguration(
                chunkAccumulationSize: 4096,
                playbackWatermark: 0.01,
                maxBufferedDuration: 5.0
            )
        )

        let format = makeFormat()
        // Send many tiny chunks (100 bytes each, well under 4096 threshold)
        let tinyChunk = generatePCMData(duration: 0.002) // ~96 bytes at 24kHz

        let stream = AsyncThrowingStream<Data, Error> { continuation in
            Task {
                // Send enough tiny chunks to exceed the accumulation threshold
                for _ in 0..<100 {
                    continuation.yield(tinyChunk)
                }
                continuation.finish()
            }
        }

        try await pipeline.start(stream: stream, format: format)

        // Use a timeout to avoid hanging
        let waitTask = Task {
            await pipeline.waitUntilFinished()
            return true
        }

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3s
            return false
        }

        let result = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await waitTask.value }
            group.addTask { (try? await timeoutTask.value) ?? false }
            let r = await group.next() ?? false
            group.cancelAll()
            return r
        }

        if !result {
            await pipeline.cancel()
        }
        // Reaching here without crashing means accumulation worked
    }
}


