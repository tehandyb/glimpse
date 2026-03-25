# Prior Art: Meta Ray-Ban Glasses + AI Integration

Research date: 2026-03-25

---

## Official SDK: Meta Wearables Device Access Toolkit (DAT)

Meta's official path for third-party developers. Released public developer preview December 2025.

- **iOS SDK**: https://github.com/facebook/meta-wearables-dat-ios (Swift Package Manager)
- **Android SDK**: https://github.com/facebook/meta-wearables-dat-android (Gradle)
- **Docs**: https://wearables.developer.meta.com/docs
- **API reference**: https://wearables.developer.meta.com/docs/reference/

**What it gives you:**
- Camera streaming via `StreamSession` — JPEG frames at ~1fps
- Audio access via iOS/Android Bluetooth profiles (microphone + speakers)
- MockDevice for testing without physical glasses

**Supported devices:** Ray-Ban Meta Gen 1 & Gen 2, Oakley Meta HSTN
**Platform requirements:** iOS 15.2+ / Android 10+
**Status:** Developer preview — you can build and test on your own glasses; public publishing to App Store/Play Store is limited to select partners for now

**Early partners:** Twitch (livestreaming), Microsoft Seeing AI (visual accessibility), Logitech Streamlabs

---

## Prior Art Projects

### VisionClaw (most complete prior art)
- **Repo**: https://github.com/sseanliu/VisionClaw (also Intent-Lab/VisionClaw)
- **Stack**: Meta DAT SDK (iOS + Android) + Gemini Live API + OpenClaw
- **Architecture**:
  - Glasses → DAT SDK → iOS/Android app
  - App sends JPEG frames (~1fps) + PCM audio (16kHz) via WebSocket to Gemini Live
  - Gemini Live returns audio responses + tool calls
  - Tool calls routed to OpenClaw Gateway (56+ skills)
- **Key detail**: Rolling window of 20 messages (10 conversation turns) for context management; session continuity via `x-openclaw-session-key` header
- **Takeaway**: Proves the full loop (vision + voice + agentic actions) works. Uses Gemini because Gemini Live has native real-time audio. We'd swap in Claude.

### VisionClaude
- **Repo**: https://github.com/mrdulasolutions/visionclaude
- **Stack**: iPhone/Meta glasses camera → Claude API via local MCP server
- **Key detail**: Uses Claude's vision API; voice in/out. More of a prototype than a complete system.

### OpenVision
- **Repo**: https://github.com/rayl15/OpenVision
- **Stack**: Meta DAT SDK (iOS) + OpenClaw + Gemini Live
- **Similar to VisionClaw** — open-source iOS app, OpenClaw tools, hands-free

### glasses-ai
- **Repo**: https://github.com/ghsaboias/glasses-ai
- **Approach**: Different from DAT — streams via Instagram Live from glasses, captures on Mac, runs YOLOv8 object detection. No real-time two-way audio.
- **Takeaway**: Instagram Live approach is a hack; DAT SDK is the right path.

### meta-glasses-api
- **Repo**: https://github.com/dcrebbin/meta-glasses-api
- **Approach**: Browser extension that intercepts the Meta AI messenger interface to reroute messages to ChatGPT/Claude. Entirely different paradigm — no vision, text relay only.
- **Takeaway**: Not relevant for vision use cases, but shows demand.

---

## Key Technical Constraints (from DAT SDK)

1. **Camera**: ~1fps JPEG frames via `StreamSession`. Not video — discrete frames. Good for vision analysis, not gesture detection.
2. **Audio in**: Microphone accessible via Bluetooth HFP/A2DP profiles — standard iOS `AVAudioSession`.
3. **Audio out**: Glasses speakers accessible via Bluetooth A2DP — route TTS audio to the glasses.
4. **Latency**: Round-trip (voice capture → AI response → TTS playback) will be 2-5 seconds depending on model and server. Claude Haiku is fastest.
5. **No persistent background streaming**: iOS background audio rules apply. App needs to be in foreground or use background audio session.
6. **Distribution**: During developer preview, can only distribute via TestFlight (not App Store public listing).

---

## What VisionClaw Solved That We Need to Solve Differently

VisionClaw uses **Gemini Live** because it has a native real-time bidirectional audio API (WebSocket, audio in/audio out simultaneously). Claude does not have an equivalent real-time audio API as of March 2026.

**Our approach for Claude:**
- STT (Speech-to-Text): Apple's native `SFSpeechRecognizer` or whisper.cpp — convert glasses microphone audio to text
- LLM: Claude API (claude-haiku-4-5 for speed, claude-sonnet-4-6 for quality) with vision — send text + JPEG frames
- TTS: Apple's `AVSpeechSynthesizer` or a faster third-party TTS — stream audio to glasses speakers

This STT → Claude → TTS pipeline adds ~1-2s latency vs Gemini Live's streaming, but gives us Claude's quality and tool use.

---

## OpenClaw Opportunity

Andrew already has OpenClaw running on the Mac mini. VisionClaw's architecture routes tool calls from the AI to OpenClaw's gateway. We can do the same — when Claude decides to take an action (send a message, search the web, control smart home), it makes a tool call that the iOS app forwards to the local OpenClaw instance over Tailscale. This gives us 56+ tools out of the box.
