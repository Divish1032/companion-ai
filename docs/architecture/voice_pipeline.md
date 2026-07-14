# Voice Pipeline Architecture

Use this file for VAD, endpointing, audio-frame handling, barge-in, and TTS chunking work.

Related sprints: Sprint -1, Sprint 3, Sprint 4, Sprint 7, Sprint 10.

## 7. VAD and Turn-Taking Requirements

### 7.1 Use VAD

VAD is required.

Use VAD for:

- Speech-start detection.
- Speech-end candidate detection.
- Barge-in detection.
- Cost gating.
- Silence handling.
- UI state changes.

### 7.2 Do Not Use VAD Alone

VAD alone is not enough for final turn-taking.

Problem examples:

- User pauses mid-thought.
- User says "haan ruk..." and continues.
- User is thinking aloud.
- Background speech/noise appears.
- Short Hindi discourse particles create ambiguous endpoints.

Required design:

```text
VAD detects speech presence.
Endpointing decides if the user turn should be committed.
STT partials and timing help endpointing.
Future turn detector can improve semantic/acoustic turn prediction.
```

Initial endpointing state machine:

```text
Idle
  -> SpeechCandidate after speech probability crosses threshold
SpeechCandidate
  -> InSpeech after >=200ms confirmed speech
  -> Idle if speech drops before confirmation
InSpeech
  -> EndpointCandidate after >=600ms silence
  -> ForcedEndpoint after max utterance duration
EndpointCandidate
  -> InSpeech if speech resumes
  -> CommitTurn if coalescing silence holds and transcript/partial does not suggest continuation
CommitTurn
  -> Thinking/LLM pipeline
```

Initial configurable parameters:

- Minimum confirmed speech before treating input as a user turn: 200ms.
- Pre-speech buffer forwarded to STT: 150-300ms to avoid clipping first syllables.
- Silence duration before endpoint candidate: 600ms.
- Extended silence for low-confidence/continuation partials: 900-1200ms.
- Turn-coalescing silence before committing a normal endpoint: 1500ms in the
  current Hindi/Hinglish route. A shorter pause keeps the same logical turn
  open so continuation does not create a second message.
- Forced endpoint timeout: 8-10s for MVP to cap cost and runaway sessions.
- Do not commit on trailing continuation particles such as "toh", "aur", "phir", "matlab", "haan..." when STT partials indicate continuation.
- Empty or very low-confidence turns should ask for repeat rather than call LLM.

### 7.3 Initial VAD Choice

Start with server-side Silero VAD because it is mature, lightweight, and easy to run on CPU.

Implementation requirements:

- Keep VAD provider pluggable.
- Benchmark VAD on noisy Hindi/Hinglish phone audio.
- Tune thresholds separately for:
  - speech start
  - speech end
  - barge-in
  - background noise rejection

### 7.4 Client-Side Audio Activity

The client should implement a lightweight audio level detector for immediate UI and local mute behavior.

Client detector must not be the final authority for endpointing.

Use it for:

- Waveform animation.
- Immediate "you are speaking" UI.
- Optional local AI playback duck/mute on likely barge-in.

Server remains authoritative.

### 7.5 Audio Frame Pipeline

Initial audio pipeline defaults:

- WebRTC/LiveKit transport uses native Opus where possible.
- User mic uplink target: mono voice, 20ms packet time, 16-24kbps effective bitrate where configurable, FEC enabled if available.
- Agent decodes incoming audio to canonical internal PCM: 16kHz, 16-bit, mono.
- VAD consumes 30ms windows over canonical PCM.
- STT receives streaming chunks around 100-200ms, plus pre-speech buffer.
- VAD and STT streaming should run concurrently once speech is confirmed; do not wait for VAD end before starting STT.
- An STT adapter that internally finalizes a segment during a natural pause
  must retain that segment and append the final trailing segment before it
  emits the logical turn's final transcript. Vosk's `Result()` is segment-level
  while `FinalResult()` may contain only the last segment; treating the former
  as a replaceable partial loses the beginning of a spoken thought.
- TTS output should be normalized to the format required by LiveKit publication in one adapter layer.
- Log sample rate, channels, bit depth, codec, and chunk sizes once per session.

---

## 8. Voice Pipeline Design

### 8.1 Normal Turn

```text
1. User audio arrives in LiveKit room.
2. Agent subscribes to user audio.
3. Audio frames pass through VAD.
4. Speech-start event emitted to client.
5. Audio stream is forwarded to STT.
6. STT partials emitted to client as partial transcript.
7. Endpointing determines final user turn.
8. Final transcript emitted to client and persisted locally.
9. LLM request starts.
10. LLM tokens stream.
11. Text chunks are buffered into TTS-friendly segments.
12. TTS streams audio.
13. Agent publishes AI audio to room.
14. Assistant transcript emitted and persisted.
```

### 8.2 Barge-In Turn

```text
1. AI is speaking.
2. User begins speaking.
3. Client audio detector may mute local playback immediately.
4. Server VAD confirms sustained speech start.
5. Agent cancels active LLM stream.
6. Agent cancels active TTS stream.
7. Agent clears pending audio frames.
8. Client clears playback queue if exposed by SDK.
9. System returns to listening state.
10. New user turn begins.
```

Barge-in requirements:

- Require around 200ms of confirmed user speech before server-side barge-in to reduce false triggers from coughs/noise.
- Client may locally duck/mute earlier for responsiveness, but server remains authoritative.
- If TTS audio is already playing, fade out over 50-80ms where possible rather than hard cutting mid-waveform.
- If LLM has started but TTS has not, cancel text generation and do not synthesize buffered text.
- If the user repeatedly interrupts rapidly, after 3 rapid barge-ins the assistant should stop responding and say a short listening prompt such as "Aap pehle boliye, main sun raha hoon."
- Log barge-in stage: before TTS, during TTS, after TTS, false/ignored.

### 8.3 Pre-response continuation coalescing

If speech resumes after an endpoint has committed but before the assistant final
response is committed, the agent:

1. Cancels the pending memory lookup, LLM stream, and TTS work.
2. Keeps the earlier logical turn ID and transcript text.
3. Appends the resumed transcript to that turn.
4. Emits one replacement final transcript event using the original turn ID.
5. Runs memory lookup and LLM inference once against the coalesced turn.

Once an assistant final transcript has been emitted, later speech is handled as
a normal barge-in/new turn. This prevents an already spoken answer from being
retroactively associated with a different user utterance. The agent emits only
redacted coalescing diagnostics: `turn_coalescing_started`, `coalesced`, and
`coalesced_segments`.

### 8.4 TTS Chunking

TTS should not wait for the entire LLM answer.

Chunking strategy:

- Start TTS after first complete phrase/sentence or a small token threshold.
- Prefer natural Hindi phrase boundaries.
- Avoid chunking in the middle of words, names, numbers, or emotional phrases.
- Keep max chunk small enough to reduce interruption waste.

Initial heuristic:

```text
Flush to TTS when:
  - punctuation boundary is reached, or
  - 300+ characters accumulated and a safe whitespace/phrase boundary exists, or
  - 1000ms since first buffered token and a safe phrase boundary exists
```

Tune based on actual Sarvam TTS latency.

Never force a TTS chunk in the middle of a Devanagari word or Romanized Hindi word. Validate chunking against actual Hindi/Hinglish LLM outputs before field testing.

---
