# StreamTTS Demo

A minimal macOS SwiftUI app for testing the StreamTTS library with real credentials.

## Prerequisites

- macOS 14+ (Sonoma or later)
- Xcode 15+
- An **ElevenLabs API key** and/or a **Google Cloud access token**

## Running the Demo

Open the demo package in Xcode:

```bash
open Examples/StreamTTSDemo/Package.swift
```

Xcode will resolve the local StreamTTS dependency automatically (it references the repo root via `../..`). Select the `StreamTTSDemo` scheme and press **Cmd+R** to build and run.

Alternatively, build and run from the command line:

```bash
cd Examples/StreamTTSDemo
swift run StreamTTSDemo
```

## Getting Credentials

### ElevenLabs

1. Sign up at [elevenlabs.io](https://elevenlabs.io)
2. Go to **Profile > API Keys** and copy your key
3. Paste the key into the "API Key" field in the app
4. The default Voice ID (`21m00Tcm4TlvDq8ikWAM`) is "Rachel"

### Google Cloud

1. Install the [gcloud CLI](https://cloud.google.com/sdk/docs/install)
2. Run `gcloud auth print-access-token` in Terminal
3. Paste the token into the "Access Token" field
4. Tokens expire after ~1 hour; generate a fresh one when needed
5. If using user credentials (not a service account), you must also fill in your **Project ID** for quota attribution

**Note:** Google Cloud TTS streaming requires macOS 15.0+ at runtime due to grpc-swift v2 transport requirements.

## Usage

1. Select a provider (ElevenLabs or Google Cloud)
2. Enter your credentials
3. Type or paste text into the text area
4. Press **Speak** (or Cmd+Return) to start streaming playback
5. Press **Stop** (or Cmd+.) to cancel mid-stream

The app breaks your text into sentences and yields them with short delays to simulate real-time LLM streaming output.
