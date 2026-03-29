# 🎤 Voice Agent MVP PRD (Interruptible + Agent Handoff)

## Overview

This project implements a **real-time, interruptible voice AI agent** that can:

1. Hold natural spoken conversations (low latency, interruptible)
2. Detect when a request requires real-world execution
3. Delegate those tasks to a **terminal-capable agent** (e.g., Claude Code)
4. Stream progress/results back into the voice conversation

---

## Core Philosophy

- **Voice layer = fast, responsive, conversational**
- **Agent layer = slow, powerful, tool-using**
- **Bridge = minimal, dumb, reliable**

We explicitly avoid building a full orchestration system in this MVP.

---

## Architecture (MVP)

```
[Browser / Client]
  - Mic input
  - Audio playback
  - Transcript UI

        │ WebRTC

[OpenAI Realtime Session]
  - Speech-to-speech conversation
  - VAD (turn detection)
  - Interruptible audio output

        │ (events)

[Thin Server Bridge]
  - Detect agent-worthy requests
  - Dispatch tasks to agent runtime
  - Stream progress + results back

        │

[Agent Runtime (Claude Code / Terminal Agent)]
  - Executes coding / system tasks
  - Uses tools (bash, file edits, etc.)
  - Returns structured outputs
```

---

## Key Features

### 1. Interruptible Voice Conversation

- Continuous audio input (mic stream)
- Streaming speech output
- User can **interrupt assistant mid-sentence**
- Assistant immediately yields (barge-in)

#### Requirements
- Latency target: < 300ms perceived
- Use VAD (built-in from realtime API)
- Playback must be cancellable instantly

---

### 2. Live Transcript

- Display:
  - User speech (live + finalized)
  - Assistant speech (streaming)
- Maintain session transcript in memory
- Persist optionally (simple DB/log)

---

### 3. Agent Handoff (Core MVP Feature)

The system supports **exactly ONE tool**:

run_agent_task(task: AgentTask)

---

## Agent Task Contract

type AgentTask = {
  objective: string;
  context?: string;
  returnMode?: "summary" | "full";
};

### Example

{
  "objective": "Find why admin users cannot insert rows in the events table and fix it",
  "context": "Next.js + Clerk + Supabase app",
  "returnMode": "summary"
}

---

## Handoff Behavior

### Trigger condition

Voice layer should call `run_agent_task` when:

- request involves:
  - coding
  - file inspection
  - terminal execution
  - multi-step reasoning with tools

### Examples

Trigger:
- "Fix this bug in my repo"
- "Check why my auth is failing"
- "Deploy this to Vercel"

Do NOT trigger:
- "Explain what this error means"
- "How does Clerk auth work?"

---

## Agent Execution Flow

```
Voice detects task
  ↓
Server receives task
  ↓
Server starts agent runtime (Claude Code or equivalent)
  ↓
Agent performs steps (tools, code edits, etc.)
  ↓
Server streams progress updates
  ↓
Server sends final result
  ↓
Voice layer speaks result
```

---

## Progress Streaming (Important)

The system must **not block while agent runs**.

### Required behavior:

Immediately after handoff:

Assistant says:
"I'm checking that now."

Then during execution:
- "I found two possible issues."
- "Looking at your middleware now."

Then final:
- "The issue is X. I prepared a fix."

---

## Bridge Responsibilities (Minimal)

The server bridge should ONLY:

1. Detect when to call agent
2. Start agent process
3. Stream progress back
4. Return final result

---

## Voice Layer Behavior

### When NOT calling agent:
- respond directly via realtime model

### When calling agent:
- acknowledge immediately
- yield control to agent updates
- resume normal conversation after completion

---

## Interruption Handling

### Rule:

If user speaks while assistant is speaking:

1. Stop audio playback immediately
2. Cancel current speech output
3. Switch to listening mode
4. Process new input

---

## UI Requirements

Minimal UI:

- 🎤 Start / Stop button
- 🔊 Speaking indicator
- 👂 Listening indicator
- ⚡ Interrupted indicator
- 📝 Transcript panel

---

## Data Logging (MVP)

Track:

- time_to_first_audio
- turn_latency
- interruption_count
- agent_tasks_triggered
- agent_task_duration

---

## Prompt Strategy

Keep prompt minimal.

---

## Non-Goals

- multi-agent orchestration
- tool registry
- long-term memory
- complex routing

---

## Summary

- real-time voice shell
- one delegation mechanism
- one powerful agent

---

## End of PRD
