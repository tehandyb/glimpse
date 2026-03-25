# Glimpse — Technical Requirements Document

**Date**: 2026-03-25
**Status**: Pre-MVP

---

## Architecture Overview

```
Meta Ray-Ban Gen 2
    │ BLE (DAT SDK)
    ▼
iOS App (Glimpse)
    │
    ├── Camera frames (JPEG ~1fps) ──────────────────────────┐
    │                                                        │
    ├── Microphone audio (HFP Bluetooth profile)             │
    │       │                                                │
    │   SFSpeechRecognizer (on-device STT)                   │
    │       │                                                │
    │   Transcribed text ─────────────────────────────► Claude API
    │                                                   (Haiku / Sonnet)
    │                                                        │
    │                                                   Tool calls (V3)
    │                                                        │
    │                                                   OpenClaw Gateway
    │                                                   (Mac mini / Tailscale)
    │                                                        │
    │   Claude text response ◄───────────────────────────────┘
    │       │
    │   AVSpeechSynthesizer (TTS)
    │       │
    ├── Speaker audio (A2DP Bluetooth profile)
    │
    ▼
Glasses speakers play response
```

---

## Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Platform | iOS (Swift, SwiftUI) | Andrew uses iPhone; Meta DAT SDK supports iOS 15.2+ |
| Glasses connectivity | Meta Wearables DAT SDK (iOS) via SPM | Official SDK — camera streaming + BLE management |
| Speech-to-text | Apple `SFSpeechRecognizer` | On-device, fast, free, handles partial results |
| LLM | Anthropic Claude API (`claude-haiku-4-5` default, `claude-sonnet-4-6` toggle) | Haiku for low latency; Sonnet for complex visual tasks |
| Vision | Claude messages API with `image/jpeg` base64 blocks | Attach JPEG frame alongside text |
| Text-to-speech | `AVSpeechSynthesizer` (iOS native) | Zero latency setup, routes to BT speakers automatically |
| Audio routing | `AVAudioSession` with `.playAndRecord` + BT override | Ensures mic in from glasses, speaker out to glasses |
| HTTP client | `URLSession` async/await | No extra dependencies |
| State management | SwiftUI `@Observable` / `@State` | Keep it simple for MVP |
| Secrets | iOS Keychain | Store Anthropic API key |

---

## Project Structure

```
glimpse/
├── Glimpse.xcodeproj
├── Glimpse/
│   ├── App/
│   │   ├── GlimpseApp.swift          # App entry, audio session setup
│   │   └── ContentView.swift         # Main UI — connection status + transcript
│   ├── Glasses/
│   │   ├── GlassesManager.swift      # DAT SDK: connect, stream frames, BLE state
│   │   └── GlassesFrame.swift        # Model: a captured JPEG + timestamp
│   ├── Audio/
│   │   ├── SpeechRecognizer.swift    # SFSpeechRecognizer wrapper, VAD, transcription
│   │   └── Speaker.swift             # AVSpeechSynthesizer wrapper, BT routing
│   ├── Claude/
│   │   ├── ClaudeClient.swift        # Anthropic messages API, vision support
│   │   └── ClaudeMessage.swift       # Request/response models
│   └── Settings/
│       └── SettingsView.swift        # API key entry, model picker
├── research/
│   └── prior-art.md
├── PRD.md
└── TRD.md
```

---

## Key Technical Details

### 1. Meta DAT SDK Integration

```swift
// Package.swift or Xcode SPM
// https://github.com/facebook/meta-wearables-dat-ios

import WearablesKit

// Connect to glasses
let deviceManager = WearablesDeviceManager()
deviceManager.startDiscovery()

// Stream camera frames
let streamSession = try await device.startStreamSession()
for await frame in streamSession.frames {
    let jpeg: Data = frame.jpegData
    // Pass to Claude client
}
```

**Frame rate**: ~1fps JPEG. Each frame is ~30-80KB. We capture the latest frame when the user finishes speaking.

### 2. Audio Pipeline

**Capture (glasses mic → STT):**
```swift
// Route audio input from glasses via BT HFP
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord,
                         mode: .default,
                         options: [.allowBluetooth, .allowBluetoothA2DP])
try session.setActive(true)

// SFSpeechRecognizer for continuous recognition
// Use .isFinal == true to detect end of utterance
```

**Playback (TTS → glasses speakers):**
```swift
let utterance = AVSpeechUtterance(string: claudeResponse)
utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
utterance.rate = 0.52  // Slightly faster than default
AVSpeechSynthesizer().speak(utterance)
// Automatically routes to active BT audio output (glasses)
```

### 3. Claude API Call

**Endpoint**: `POST https://api.anthropic.com/v1/messages`

**Request shape** (vision + text):
```json
{
  "model": "claude-haiku-4-5-20251001",
  "max_tokens": 300,
  "system": "You are a voice assistant running on smart glasses. Respond concisely — your answers are spoken aloud. 1-3 sentences unless more is clearly needed.",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "image",
          "source": {
            "type": "base64",
            "media_type": "image/jpeg",
            "data": "<base64-encoded-frame>"
          }
        },
        {
          "type": "text",
          "text": "<transcribed speech>"
        }
      ]
    }
  ]
}
```

**Response**: Extract `content[0].text`, pass to TTS.

**Latency budget (target <5s):**
- STT (end of utterance detection): 0.5-1s
- JPEG capture + encode: <0.1s
- API call (Haiku): 1-2s
- TTS first word: <0.5s
- **Total**: ~2-4s

### 4. Voice Activity Detection (VAD)

Use `SFSpeechRecognizer` in continuous mode with a silence timer:
- Start listening on app foreground / glasses connect
- When `isFinal == true` OR 1.5s of silence after last partial result → capture frame + send to Claude
- Resume listening after TTS completes

No wake word for MVP. (V2 consideration: wake word detection with `SFSoundAnalysisRequest` or `SNClassifySoundRequest`)

### 5. Background Operation

iOS requires a background mode to keep running while pocketed:
- Enable **Background Modes** → **Audio, AirPlay, and Picture in Picture** in Xcode capabilities
- Maintain `AVAudioSession` active throughout
- This is the same pattern used by Siri, Spotify, and voice recorder apps

### 6. OpenClaw Integration (V3)

When Claude returns tool calls, the app POSTs to OpenClaw's gateway:
```
POST http://<tailscale-ip>:3000/execute
{
  "tool": "send_imessage",
  "args": { "to": "+12404225614", "message": "On my way" }
}
```
Claude tool definitions mirror OpenClaw's available skills. The session key (`x-openclaw-session-key`) maintains conversational context across tool calls.

---

## MVP Scope (What We're Building First)

1. iOS app that connects to glasses via DAT SDK
2. BT audio routing (mic in from glasses, TTS out to glasses speakers)
3. VAD: detect when user finishes speaking
4. Capture latest camera frame at that moment
5. Send frame + transcript to Claude (Haiku), receive text response
6. Speak response through glasses via TTS
7. Simple UI: connection status, live transcript, last Claude response

**Not in MVP:**
- Conversation history / memory
- OpenClaw tool calls
- Wake word
- Settings UI (API key hardcoded in `.env`-equivalent / Keychain)

---

## Development Setup

### Prerequisites
- Xcode 16+
- iPhone with iOS 15.2+ (for testing)
- Meta Ray-Ban Gen 2 glasses
- Anthropic API key
- Meta developer account (register app at developers.meta.com/wearables)

### Getting Started
```bash
cd glimpse
# Open Xcode project
open Glimpse.xcodeproj

# Add Meta DAT SDK via SPM
# Package URL: https://github.com/facebook/meta-wearables-dat-ios
# Or use MockDevice for testing without glasses
```

### App Registration
Meta requires registering your app at developers.meta.com/wearables before the DAT SDK will connect to real glasses. You'll get an App ID to embed in the Xcode project.
