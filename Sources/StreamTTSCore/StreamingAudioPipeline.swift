import AVFoundation

/// Configuration for the audio pipeline buffering, backpressure, and engine management.
public struct AudioPipelineConfiguration: Sendable {
    /// Bytes to accumulate before feeding to AVAudioConverter.
    public var chunkAccumulationSize: Int = 4096

    /// Minimum duration of converted audio required in the player queue before playback starts.
    public var playbackWatermark: TimeInterval = 0.5

    /// Maximum duration of audio to buffer ahead of playback. Provides backpressure to the network stream.
    public var maxBufferedDuration: TimeInterval = 3.0

    /// Whether to automatically start/stop AVAudioEngine.
    /// Set to false if the host app manages its own audio session.
    public var managesAudioEngine: Bool = true
    
    /// Creates a new pipeline configuration.
    /// - Parameters:
    ///   - chunkAccumulationSize: Bytes to accumulate before feeding to AVAudioConverter.
    ///   - playbackWatermark: Minimum duration of converted audio required in the player queue before playback starts.
    ///   - maxBufferedDuration: Maximum duration of audio to buffer ahead of playback. Provides backpressure to the network stream.
    ///   - managesAudioEngine: Whether to automatically start/stop AVAudioEngine.
    public init(
        chunkAccumulationSize: Int = 4096,
        playbackWatermark: TimeInterval = 0.5,
        maxBufferedDuration: TimeInterval = 3.0,
        managesAudioEngine: Bool = true
    ) {
        self.chunkAccumulationSize = chunkAccumulationSize
        self.playbackWatermark = playbackWatermark
        self.maxBufferedDuration = maxBufferedDuration
        self.managesAudioEngine = managesAudioEngine
    }
}

/// A provider-agnostic actor that buffers PCM chunks, converts sample format, and schedules playback on `AVAudioEngine`.
public actor StreamingAudioPipeline {
    private let configuration: AudioPipelineConfiguration
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    private var isPlaying = false
    private var isFinished = false
    private var streamTask: Task<Void, Error>?
    
    private var converter: AVAudioConverter?
    
    // Backpressure and buffering state
    private var queuedDuration: TimeInterval = 0 // scheduled but not played
    private var scheduledCount = 0
    private var completedCount = 0
    
    private var backpressureContinuation: CheckedContinuation<Void, Never>?
    private var finishedContinuation: CheckedContinuation<Void, Never>?

    /// Creates a new streaming audio pipeline.
    /// - Parameter configuration: The configuration for the pipeline.
    public init(configuration: AudioPipelineConfiguration = .init()) {
        self.configuration = configuration
        engine.attach(playerNode)
    }
    
    /// Starts the pipeline, reading from the stream, converting, and playing.
    public func start(
        stream: AsyncThrowingStream<Data, Error>,
        format: AVAudioFormat
    ) async throws {
        // Prepare target format (Float32 at device sample rate, matching mixer)
        let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        
        guard let outFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: mixerFormat.sampleRate > 0 ? mixerFormat.sampleRate : 44100.0,
            channels: format.channelCount,
            interleaved: false
        ) else {
            throw StreamTTSError.formatConversionFailed(from: format, to: mixerFormat)
        }
        
        guard let audioConverter = AVAudioConverter(from: format, to: outFormat) else {
            throw StreamTTSError.formatConversionFailed(from: format, to: outFormat)
        }
        self.converter = audioConverter
        
        engine.connect(playerNode, to: engine.mainMixerNode, format: outFormat)
        
        if configuration.managesAudioEngine {
            do {
                engine.prepare()
                try engine.start()
            } catch {
                throw StreamTTSError.audioEngineSetupFailed(underlying: error)
            }
        }
        
        var accumulator = AudioBufferAccumulator(
            threshold: configuration.chunkAccumulationSize,
            format: format
        )
        
        self.streamTask = Task {
            do {
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    let blocks = accumulator.append(chunk)
                    for block in blocks {
                        try await processBlock(block, inputFormat: format, outFormat: outFormat, audioConverter: audioConverter)
                    }
                }
                if let lastBlock = accumulator.flush() {
                    try await processBlock(lastBlock, inputFormat: format, outFormat: outFormat, audioConverter: audioConverter)
                }
                
                self.isFinished = true
                
                // If we finished streaming and there is nothing scheduled, just start playing if needed or complete
                if scheduledCount == 0 || scheduledCount == completedCount {
                    self.checkFinished()
                } else if !self.isPlaying {
                    self.playerNode.play()
                    self.isPlaying = true
                }
            } catch {
                // Handle error from the stream, stop everything
                self.cancel()
                throw error
            }
        }
    }
    
    private func processBlock(_ block: Data, inputFormat: AVAudioFormat, outFormat: AVAudioFormat, audioConverter: AVAudioConverter) async throws {
        // Wait if backpressure is active
        if queuedDuration >= configuration.maxBufferedDuration {
            await withCheckedContinuation { continuation in
                self.backpressureContinuation = continuation
            }
        }
        
        // 1. Wrap block in AVAudioPCMBuffer matching inputFormat
        let frameCount = AVAudioFrameCount(block.count / Int(inputFormat.streamDescription.pointee.mBytesPerFrame))
        guard let inBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else {
            return
        }
        inBuffer.frameLength = frameCount
        
        block.withUnsafeBytes { raw in
            guard let src = raw.baseAddress else { return }
            let audioBuffer = inBuffer.audioBufferList.pointee.mBuffers
            memcpy(audioBuffer.mData, src, block.count)
        }
        
        // 2. Convert to outFormat
        // Capacity: original frames * (out sample rate / in sample rate), with a little padding
        let ratio = outFormat.sampleRate / inputFormat.sampleRate
        let outFrameCapacity = AVAudioFrameCount(Double(frameCount) * ratio) + 1024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outFrameCapacity) else {
            return
        }
        
        class ConversionState { var hasProvidedData = false }
        let state = ConversionState()
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            if state.hasProvidedData {
                outStatus.pointee = .noDataNow
                return nil
            }
            state.hasProvidedData = true
            outStatus.pointee = .haveData
            return inBuffer
        }
        
        audioConverter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)
        if let _ = error {
            throw StreamTTSError.formatConversionFailed(from: inputFormat, to: outFormat)
        }
        
        // 3. Schedule on playerNode
        let duration = Double(outBuffer.frameLength) / outFormat.sampleRate
        self.queuedDuration += duration
        self.scheduledCount += 1
        
        playerNode.scheduleBuffer(outBuffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.bufferCompleted(duration: duration)
            }
        }
        
        // 4. Start playback if watermark reached
        if !isPlaying && queuedDuration >= configuration.playbackWatermark {
            playerNode.play()
            isPlaying = true
        }
    }
    
    private func bufferCompleted(duration: TimeInterval) {
        queuedDuration -= duration
        completedCount += 1
        
        // Resume stream if we were suspended for backpressure
        if queuedDuration < configuration.maxBufferedDuration {
            if let continuation = backpressureContinuation {
                backpressureContinuation = nil
                continuation.resume()
            }
        }
        
        checkFinished()
    }
    
    private func checkFinished() {
        if isFinished && completedCount >= scheduledCount {
            if let continuation = finishedContinuation {
                finishedContinuation = nil
                continuation.resume()
            }
            if configuration.managesAudioEngine {
                engine.stop()
            }
        }
    }
    
    /// Waits until all scheduled audio has finished playing.
    public func waitUntilFinished() async {
        if isFinished && completedCount >= scheduledCount { return }
        await withCheckedContinuation { continuation in
            self.finishedContinuation = continuation
        }
    }
    
    /// Cancels the pipeline, stopping playback immediately and tearing down the engine if managed.
    public func cancel() {
        streamTask?.cancel()
        playerNode.stop()
        if configuration.managesAudioEngine {
            engine.stop()
        }
        isPlaying = false
        
        if let continuation = backpressureContinuation {
            backpressureContinuation = nil
            continuation.resume()
        }
        if let continuation = finishedContinuation {
            finishedContinuation = nil
            continuation.resume()
        }
    }
}
