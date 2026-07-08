# companion_mobile

Flutter shell for the Companion AI voice-only MVP.

## Sprint 3 Scope

- Opens directly to `VoiceChatHomeScreen`.
- Uses Riverpod for app/session state.
- Uses local Drift/SQLite transcript storage.
- Generates an anonymous device ID in platform secure storage.
- Requests microphone permission after first-session privacy consent.
- Creates an anonymous API session and joins a local self-hosted LiveKit room.
- Publishes microphone audio through LiveKit/native WebRTC.
- Sends bounded recent local transcript context when a voice session starts.
- Adds reliable and lossy LiveKit data-channel abstractions with sequence dedupe.
- Consumes realtime-agent `session_state` and `error` data-channel events.
- STT/LLM/TTS/VAD and real backend voice intelligence are not implemented in Sprint 3.
- Provides clear history and a bad-transcript re-speak affordance.
- Keeps the transcript simulation helper clearly labelled as dev-only.

## Local LiveKit Run

Start the local stack from the repo root:

```bash
make dev
```

Run the app with the API base URL if the default `http://localhost:8000` is not
reachable from the device. Android emulators usually need:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Local Storage Encryption Plan

Sprint 1 creates the Drift schema and migration hook but does not enable encrypted
SQLite. Before real-user field testing, transcript storage must either be moved
to SQLCipher or equivalent encrypted SQLite with the key stored in platform
secure storage, or testing must be restricted to non-sensitive scripted
conversations. This app does not claim field-test storage readiness yet.

## Barge-In Mute/Duck Benchmark

The local mute/duck path cannot be meaningfully benchmarked in Sprint 1 without a
real playback path and a device/emulator run that exercises Flutter/plugin/native
timing. The baseline `audio_session` configuration is present. Re-run the
benchmark after Sprint 2/3 audio playback exists, measuring command issue time,
native/plugin acknowledgement time, and audible mute/duck completion on Android
and iOS hardware.
