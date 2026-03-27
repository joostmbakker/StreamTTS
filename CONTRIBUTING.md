# Contributing to StreamTTS

## Getting Started

```bash
git clone <repo-url>
cd StreamTTS
swift build
swift test
```

Tests that require live API credentials (`ELEVENLABS_API_KEY`, `GOOGLE_TTS_ACCESS_TOKEN`) are automatically skipped via `XCTSkip` when the environment variables are not set.

## Adding a New Provider Adapter

1. **Create a new target** in `Package.swift`:
   ```swift
   .target(
       name: "StreamTTSMyProvider",
       dependencies: ["StreamTTSCore"]
   ),
   .testTarget(
       name: "StreamTTSMyProviderTests",
       dependencies: ["StreamTTSMyProvider"]
   ),
   ```

2. **Conform to `TTSProvider`** in your adapter. The protocol requires:
   - `var outputFormat: AVAudioFormat` — the PCM format your provider emits.
   - `func stream(text: AsyncStream<String>) -> AsyncThrowingStream<Data, Error>` — consume text chunks, return PCM audio data.

3. **Add a configuration struct** for any provider-specific settings (API keys, voice IDs, model selection).

4. **Write tests** — at minimum, a live integration test gated behind an environment variable, and unit tests for any configuration or parsing logic.

See `Sources/StreamTTSElevenLabs/` for a complete reference implementation using WebSockets with zero external dependencies.

## Code Style

- Swift 5.9+, targeting iOS 16 / macOS 13.
- Use Swift Concurrency exclusively: `async/await`, `AsyncStream`, `actor`. No Combine, no GCD.
- All public types must be `Sendable`.
- Add `///` doc comments on all public APIs.
- Match the existing code style — no SwiftLint configuration yet.

## Pull Request Process

1. Fork the repository and create a feature branch.
2. Make your changes in focused, atomic commits.
3. Ensure `swift build` and `swift test` pass locally.
4. Open a PR against `dev`. Include a description of what changed and why.
5. All PRs must pass CI checks before merging.
6. Include tests for new functionality.

## Reporting Issues

Use GitHub Issues. Please include:

- Swift version (`swift --version`)
- Platform and OS version
- A minimal reproduction case
- Expected vs. actual behavior
