# Glimpse

Claude, through your eyes. An iOS app that connects Meta Ray-Ban Gen 2 glasses to Claude.

Speak naturally. Claude sees what you see (camera frame) and hears what you say. Response plays through your glasses speakers. Phone stays in your pocket.

---

## Setup

### Prerequisites
- Xcode 16+
- iPhone (iOS 16+)
- Meta Ray-Ban Gen 2 smart glasses
- Anthropic API key
- Meta developer account (register at developers.meta.com/wearables)

### 1. Bootstrap

```bash
bash bootstrap.sh
```

This creates `Secrets.xcconfig` from the example template and regenerates `Glimpse.xcodeproj`. Requires [xcodegen](https://github.com/yonaskolb/XcodeGen) (installed automatically via Homebrew if missing).

### 2. Add your Meta credentials

Go to https://developers.meta.com/wearables/ and create an app. You'll get a **Meta App ID** and **client token** — paste them into `Secrets.xcconfig`:

```
META_APP_ID = <your app id>
META_CLIENT_TOKEN = <your client token>
```

### 3. Open in Xcode

```bash
open Glimpse.xcodeproj
```

The Meta Wearables DAT SDK is pulled via Swift Package Manager from `https://github.com/facebook/meta-wearables-dat-ios`.

### 4. Add your Anthropic API key

Run the app → tap the gear icon → enter your `sk-ant-...` key.

### 5. Enable capabilities in Xcode

In the target settings → Signing & Capabilities, add:
- Background Modes → Audio, AirPlay, and Picture in Picture
- Bluetooth

---

## Architecture

```
Glasses (BLE via DAT SDK)
  └── Camera frames (~1fps JPEG)
  └── Mic audio (Bluetooth HFP)
        └── SFSpeechRecognizer (on-device STT)
              └── Claude API (Haiku or Sonnet) + JPEG frame
                    └── Text response
                          └── AVSpeechSynthesizer → Glasses speakers (BT A2DP)
```

## Files

```
Glimpse/
├── App/
│   ├── GlimpseApp.swift        # Entry point, audio session setup
│   ├── GlimpseViewModel.swift  # Main pipeline: STT → Claude → TTS
│   └── ContentView.swift       # UI: status, transcript, response
├── Glasses/
│   ├── GlassesManager.swift    # DAT SDK: BLE connect + frame streaming
│   └── GlassesFrame.swift      # JPEG frame model
├── Audio/
│   ├── SpeechRecognizer.swift  # STT + 1.5s silence VAD
│   └── Speaker.swift           # TTS + Bluetooth audio routing
├── Claude/
│   ├── ClaudeClient.swift      # Anthropic messages API, Keychain key storage
│   └── ClaudeMessage.swift     # Request/response models
└── Settings/
    └── SettingsView.swift      # API key + model picker
```

## Roadmap

- **MVP (now)**: Sight + voice — camera frame + speech → Claude → spoken response
- **V2**: Persistent memory, conversation history across sessions
- **V3**: OpenClaw tool use — send iMessages, web search, smart home, reminders (via Tailscale to Mac mini)
