# Glimpse — Product Requirements Document

**Project**: Glimpse
**Tagline**: Claude, through your eyes
**Date**: 2026-03-25
**Status**: Pre-MVP

---

## What Is This

Glimpse is an iOS app that connects your Meta Ray-Ban Gen 2 smart glasses to Claude. You wear the glasses, speak naturally, and Claude sees what you see and hears what you say — then responds through your glasses speakers. No phone in hand, no screen required.

Unlike the built-in Meta AI, Glimpse uses Claude as the intelligence layer and integrates with your existing tools (via OpenClaw) to actually take actions in the world.

---

## Problem

The Meta Ray-Ban Gen 2 glasses ship with Meta AI baked in. Meta AI is decent for casual queries but:
- Can't be customized or extended
- Doesn't connect to your personal data or tools
- Is not Claude — lower reasoning quality, no tool use beyond Meta's walled garden
- No developer access to build on top of it

Meta just shipped a developer SDK (DAT) that unlocks the hardware: camera frames + audio in/out. That's the opening.

---

## Who Is This For

Primary user: Andrew (the builder). Initially a personal tool to dog-food and refine before considering broader distribution.

Secondary user: technically sophisticated early adopters who have Ray-Ban Meta glasses and want a more powerful, extensible AI assistant than Meta AI.

---

## Core User Experience

1. Put on glasses
2. Open Glimpse on phone (runs in background while phone is pocketed)
3. Speak naturally: "What's on this menu?", "Who is this person?", "Draft a reply to that email I see"
4. Claude responds via glasses speakers
5. If an action is needed (send a message, set a reminder, look something up), Claude does it

The phone stays in your pocket. The app is a bridge, not a screen.

---

## Use Cases (MVP → V2 → V3)

### MVP — Sight + Voice
- Visual Q&A: "What does this sign say?", "What's this plant?", "Translate this"
- Context-aware answers using the camera frame + voice
- Response read aloud through glasses speakers

### V2 — Memory + Context
- Persistent memory: Claude remembers names, preferences, ongoing tasks
- Conversation history across sessions
- "Remind me of this later" → creates a reminder

### V3 — Agentic (OpenClaw integration)
- Tool calls routed to OpenClaw on Mac mini over Tailscale
- Send iMessages, search the web, control smart home, create calendar events
- "Hey, text Sarah that I'm 10 minutes away" — works hands-free

---

## Non-Goals

- Not a replacement for the Meta AI app (no intent to conflict with Meta's ToS)
- Not a real-time video analysis tool (1fps is the DAT SDK limit; good for stills, not motion)
- Not for public App Store distribution during developer preview phase
- No Android MVP (iOS first because Andrew has iPhone)

---

## Success Criteria (MVP)

- App pairs with glasses via DAT SDK
- Voice input captured from glasses mic (or phone mic as fallback)
- Camera frame captured on voice trigger
- Claude responds with relevant answer using both voice text and image
- Response plays through glasses speakers
- End-to-end round-trip under 5 seconds on good WiFi/LTE

---

## Constraints

- Meta DAT SDK developer preview: TestFlight distribution only, no public App Store
- ~1fps camera — captures a moment, not a stream
- iOS background mode: app must use background audio session to keep running pocketed
- Claude has no real-time streaming audio API (must use STT → Claude → TTS pipeline)
- OpenClaw tools require Tailscale connectivity to Mac mini (V3 constraint)
