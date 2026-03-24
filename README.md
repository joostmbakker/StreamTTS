# StreamTTS

StreamTTS is a Swift Package Manager (SPM) library that provides a provider-agnostic, streaming text-to-speech pipeline for iOS (16+) and macOS (13+).

It decouples network-level TTS ingestion from Core Audio hardware rendering. This allows developers to pipe text chunks—such as those streamed from an LLM response—into a simple API and receive real-time audio playback with sub-second time-to-first-audio.

## Features

- **Provider-Agnostic Audio Pipeline:** Core module buffers PCM chunks, converts sample formats, and schedules playback on `AVAudioEngine`.
- **Built-in Backpressure:** Prevents memory overflow by suspending provider stream consumption when audio buffer gets too far ahead.
- **Async/Await based:** Uses Swift Concurrency (no Combine, GCD, or manual locks).
- **Official Adapters:** Comes with official adapters for ElevenLabs and Google Cloud TTS.
- **Bring Your Own Provider:** Easy protocol to integrate your own custom endpoints or TTS providers.

## Installation

Add StreamTTS to your Swift project using the Swift Package Manager. In your `Package.swift` file, add:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/StreamTTS.git", from: "1.0.0")
]
```

You can selectively import what you need:
- `StreamTTSCore`: The audio pipeline and core protocols (Zero external dependencies).
- `StreamTTSElevenLabs`: Native WebSocket integration for ElevenLabs.
- `StreamTTSGoogleCloud`: gRPC integration for Google Cloud Text-to-Speech.

---

## Usage

### 1. ElevenLabs

The ElevenLabs adapter connects via WebSockets natively without any third-party networking libraries.

```swift
import StreamTTSCore
import StreamTTSElevenLabs

let config = ElevenLabsConfiguration(apiKey: "YOUR_ELEVENLABS_API_KEY", voiceId: "21m00Tcm4TlvDq8ikWAM")
let provider = ElevenLabsTTSAdapter(configuration: config)

let controller = StreamingTTSController(provider: provider)

// Start playback and the underlying stream
try await controller.start()

// Yield text chunks as they arrive from your LLM
controller.yield(text: "Hello there! ")
controller.yield(text: "This is streaming playback.")

// Inform the controller there's no more text coming
controller.finish()

// Optionally wait for audio to finish playing
await controller.waitUntilFinished()
```

### 2. Google Cloud TTS

The Google Cloud adapter uses gRPC. You must provide an OAuth2 access token via the `GoogleAuthProvider` protocol.

```swift
import StreamTTSCore
import StreamTTSGoogleCloud

// 1. Provide OAuth tokens
struct MyAuthProvider: GoogleAuthProvider {
    func accessToken() async throws -> String {
        return "YOUR_OAUTH2_TOKEN"
    }
}

// 2. Configure the adapter
var config = GoogleCloudTTSConfiguration()
config.voice = .init(languageCode: "en-US", name: "en-US-Neural2-A")

let provider = GoogleCloudTTSAdapter(
    configuration: config, 
    authProvider: MyAuthProvider()
)

let controller = StreamingTTSController(provider: provider)

// 3. Start & Yield
try await controller.start()

controller.yield(text: "This text is synthesized ")
controller.yield(text: "and played back in real time.")

controller.finish()
```

---

## Bring Your Own Provider

You can use the StreamTTS core pipeline with any custom backend. Just conform to the `TTSProvider` protocol.

```swift
import AVFoundation
import StreamTTSCore

struct MyCustomTTSProvider: TTSProvider {
    
    // 1. Specify the audio format your backend returns
    var outputFormat: AVAudioFormat {
        return AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 24000,
            channels: 1,
            interleaved: false
        )!
    }

    // 2. Implement the stream conversion
    func stream(text: AsyncStream<String>) -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Setup your connection (WebSocket, gRPC, REST SSE)
                    let connection = MyBackendConnection()
                    try await connection.connect()

                    // Process text chunks
                    for await chunk in text {
                        try await connection.send(text: chunk)
                    }
                    try await connection.finish()

                    // Receive audio chunks and yield them to the pipeline
                    for try await audioData in connection.audioStream {
                        continuation.yield(audioData)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            // Clean up when the pipeline cancels the stream
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
```

Simply pass `MyCustomTTSProvider()` into the `StreamingTTSController` and you're good to go!

## Architecture

At the heart of the library is `StreamingAudioPipeline`, an isolated actor responsible for:
1. Accumulating arbitrary byte chunks into aligned frames.
2. Wrapping bytes into `AVAudioPCMBuffer` instances.
3. Automatically converting from the provider's native format into the device's main mixer format (`Float32`).
4. Enforcing backpressure (pausing network ingestion if the audio queue grows too large).
5. Waiting for a "playback watermark" to prevent audio stuttering on slow networks.

Read `SPEC.md` for a complete architectural breakdown.
