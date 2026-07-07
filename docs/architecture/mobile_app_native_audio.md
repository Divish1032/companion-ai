# Mobile App and Native Audio Architecture

Use this file for Flutter UI, local storage, Android/Kotlin audio behavior, iOS/Swift audio behavior, and platform boundaries.

Related sprints: Sprint 1, Sprint 2, Sprint 10.

## 10. Flutter App Requirements

### 10.1 Project Structure

Suggested structure:

```text
apps/mobile/
  lib/
    main.dart
    app.dart
    core/
      config/
      logging/
      permissions/
      theme/
    features/
      voice_chat/
        data/
        domain/
        presentation/
      chat_history/
        data/
        domain/
      livekit_session/
        data/
        domain/
```

### 10.2 UI Principles

- Minimal surface.
- Production-ready polish.
- No marketing page.
- No text input.
- Large accessible voice control.
- Clear state feedback.
- Chat history readable on small phones.
- Avoid heavy animations.
- Avoid battery-heavy waveform rendering.
- Respect safe areas.
- Support dark mode if easy, but do not delay MVP.

### 10.3 Required Screens

Only one main screen is required:

```text
VoiceChatHomeScreen
```

Optional lightweight screens/sheets:

- Permission rationale sheet.
- Settings bottom sheet.
- Clear history confirmation.
- Diagnostics/debug sheet in dev builds.

### 10.4 Local Persistence

Use Drift/SQLite.

Persistence requirements:

- Include schema versioning and an `onUpgrade` migration path from Sprint 1.
- For throwaway prototype builds, recreate-on-migration is acceptable only if documented.
- Before field testing with real users, encrypt transcript storage with SQLCipher or an equivalent approach, or restrict testing to non-sensitive scripted conversations.
- Store encryption keys in platform secure storage when local DB encryption is enabled.

Tables:

```text
chat_sessions
  id TEXT PRIMARY KEY
  started_at INTEGER
  ended_at INTEGER NULL
  language TEXT

chat_messages
  id TEXT PRIMARY KEY
  session_id TEXT
  turn_id TEXT
  role TEXT
  text TEXT
  status TEXT
  language TEXT
  created_at INTEGER
  latency_json TEXT NULL
```

### 10.5 Platform Audio Requirements

Android:

- Handle microphone permission.
- Handle foreground/background transitions.
- Handle wired and Bluetooth audio routing.
- Validate behavior on low-end Android phones.
- Configure required Android manifest permissions.
- Use Android foreground service only if the app must keep an active voice session while screen is off or app is backgrounded.
- Surface native audio route changes to Flutter if LiveKit/plugin events are insufficient.
- If foreground service is enabled, use `foregroundServiceType` including `microphone` and `mediaPlayback` where required.
- Use a visible notification channel for active sessions.
- Initial notification text: "AI companion se baatcheet jaari hai".
- Test on at least one budget Android device under INR 12,000 if available.
- Audio route test must cover speaker -> wired earphones -> Bluetooth -> speaker without crashing or losing session.

iOS:

- Configure `AVAudioSession` through Flutter/native integration.
- Initial configuration candidate: category `.playAndRecord`, mode `.spokenAudio`, options `.allowBluetooth`, `.allowBluetoothA2DP`, `.defaultToSpeaker`.
- Test `.spokenAudio` versus `.voiceChat` because `.voiceChat` may improve echo cancellation but can affect TTS quality.
- Handle microphone permission.
- Handle app foreground/background transitions.
- Handle speaker, wired earphones, AirPods/Bluetooth routing.
- Validate iOS interruption events such as incoming calls, Siri, and route changes.
- MVP default: if iOS app backgrounds during an active session for more than 30s, gracefully end the session and show "Session ended because the app was backgrounded."
- Configure required `Info.plist` microphone text. Background audio settings are added only if background voice sessions become explicit MVP scope.
- Surface `AVAudioSession` interruption and route-change events to Flutter if plugin events are insufficient.
- On interruption began: pause AI playback and hold session for up to 15s.
- On interruption ended with resume allowed: resume only if within the hold window; otherwise end gracefully.

Both platforms:

- Keep audio capture/playback stable during LiveKit reconnects.
- Avoid heavy local ML processing.
- Avoid raw audio persistence.

### 10.6 Native Platform Layer Requirements

Default approach:

- Flutter owns UI, app state, chat history presentation, and high-level session commands.
- Native/WebRTC layers own latency-critical audio capture, playback, routing, interruption handling, and background-session behavior.
- Start with LiveKit Flutter APIs only where they delegate media work to native WebRTC rather than processing audio frames in Dart.
- Do not process raw realtime audio frames in Dart for core voice-loop behavior.
- Create custom native Kotlin/Swift modules when a required latency-critical behavior would otherwise depend on slow or unreliable Flutter/plugin event timing.
- Keep native code small, isolated, and covered by manual device tests.

Latency-critical native boundary:

- Barge-in local mute/duck should be native or native-backed if Flutter event timing is not consistently below target.
- Audio route changes should be detected natively and surfaced to Flutter as state events.
- Audio focus/session interruptions should be handled natively first, then reported to Flutter.
- Background/locked-screen active voice sessions require native Android/iOS lifecycle support.
- Flutter should not be responsible for sample-level audio processing, jitter buffering, echo cancellation, or playback queue timing.

Native Kotlin may be required for:

- Android foreground service for ongoing voice sessions when screen is off or app is backgrounded.
- Reliable audio focus handling.
- Bluetooth/wired headset route-change events if Flutter plugin coverage is insufficient.
- App lifecycle hooks that need to inform the LiveKit session.
- Optional native event channel for low-latency barge-in/audio route diagnostics.
- Native-backed immediate speaker mute/duck command for barge-in if plugin-level control is too slow.

Native Swift may be required for:

- `AVAudioSession` category/mode/options configuration beyond what `audio_session` handles.
- Handling interruptions from calls, Siri, alarms, and route changes.
- Background audio mode configuration if voice sessions continue while app is backgrounded.
- Optional native event channel for route/interruption diagnostics.
- Native-backed immediate speaker mute/duck command for barge-in if plugin-level control is too slow.

MVP decision:

- Native platform setup is in scope.
- Latency-critical platform audio control is in scope.
- Heavy custom native DSP/audio processing is out of scope.
- Always-on background conversation is not required for the first demo unless explicitly requested.
- If background conversation becomes required, implement Android foreground service and iOS background audio support as a dedicated hardening task, not as hidden work inside the Flutter UI sprint.

### 10.7 App Events

The app consumes backend/agent events over LiveKit data channel.

Use two event paths:

- Reliable ordered channel for `session_state`, `transcript_final`, `error`, and critical control events.
- Fast lossy/unordered channel for `transcript_partial`, audio-level updates, and non-critical live diagnostics.

The client must deduplicate events by `session_id`, `turn_id`, and `sequence`.

All events should include:

- `type`
- `sequence`
- `timestamp_ms`
- `session_id` when applicable
- `turn_id` when applicable
- schema version if the payload may evolve

```json
{
  "type": "session_state",
  "sequence": 12,
  "session_id": "session_123",
  "state": "listening",
  "schema_version": 1,
  "timestamp_ms": 0
}
```

```json
{
  "type": "transcript_partial",
  "sequence": 13,
  "session_id": "session_123",
  "turn_id": "turn_123",
  "role": "user",
  "text": "haan mujhe lagta hai",
  "schema_version": 1,
  "timestamp_ms": 0
}
```

```json
{
  "type": "transcript_final",
  "sequence": 14,
  "session_id": "session_123",
  "turn_id": "turn_123",
  "role": "user",
  "text": "haan mujhe lagta hai aaj mood thoda off hai",
  "schema_version": 1,
  "timestamp_ms": 0
}
```

```json
{
  "type": "latency_metrics",
  "sequence": 15,
  "session_id": "session_123",
  "turn_id": "turn_123",
  "schema_version": 1,
  "metrics": {
    "vad_start_ms": 80,
    "endpoint_delay_ms": 310,
    "stt_final_ms": 620,
    "llm_first_token_ms": 280,
    "tts_first_audio_ms": 470,
    "first_playback_ms": 980
  }
}
```

```json
{
  "type": "error",
  "sequence": 16,
  "session_id": "session_123",
  "turn_id": "turn_123",
  "code": "stt_provider_timeout",
  "recoverable": true,
  "message": "Speech service timed out. Please try again.",
  "schema_version": 1,
  "timestamp_ms": 0
}
```

---
