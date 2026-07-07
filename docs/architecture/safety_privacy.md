# Safety and Privacy Architecture

Use this file for safety, consent, privacy, and field-test readiness work.

## Privacy Requirements

MVP must:

- Not store raw audio.
- Store transcripts locally.
- Expose a clear chat history control.
- Show concise privacy copy before or during first microphone/session start.
- Explain that voice/transcripts are sent to backend and AI providers for processing.
- Use TLS for backend APIs.
- Avoid logging sensitive transcripts in production logs by default.
- Use redacted logs for metrics.
- Encrypt local transcript storage or explicitly document why encryption is deferred for prototype-only builds.
- Link or reference AI provider data-handling policies before field testing.

Minimum first-session consent copy:

```text
Your voice and transcript are sent to our server and AI providers to understand and respond.
We do not store raw audio in this MVP. Chat history is saved on this device.
You can clear chat history anytime.
Tap Agree to continue.
```

DPDP readiness requirements for field testing:

- Record user consent locally with timestamp and copy version.
- Provide clear history as local erasure.
- Provide contact/grievance details in settings or privacy copy, even if minimal during MVP.
- Maintain a list of third-party processors used for STT, LLM, and TTS.
- Add breach/incident response ownership before broad beta.

## Anonymous Device Identity

- Generate a random anonymous device ID on first app launch.
- Store it in secure local storage.
- Do not derive it from phone number, email, advertising ID, contacts, IMEI, or other PII.
- Use it for session creation, rate limiting, and debugging.
- Treat it as resettable if the app is deleted/reinstalled.
- Do not use it as a long-term user profile without later consent/auth changes.
- Do not log the anonymous device ID next to raw transcript text.
- Use separate opaque session IDs for metrics where possible.

## Safety Pipeline

Safety is a pipeline stage, not only prompt text:

```text
STT transcript
  -> input safety checks
  -> LLM generation when allowed
  -> output safety checks
  -> TTS only after safety approval or safety override
```

Minimum safety behavior:

- Do not provide self-harm instructions.
- For crisis/self-harm intent, respond supportively and encourage contacting local emergency support or a trusted person.
- Avoid sexual content with minors.
- Avoid medical/legal/financial certainty.
- Avoid manipulative emotional dependency.
- Do not claim to be a real human.

## Crisis Detection

Start with deterministic Hindi/Hinglish keyword and phrase matching plus a lightweight semantic classifier when available.

Examples to detect:

- `main mar jaana chahta hoon`
- `jeene ka mann nahi karta`
- `sab khatam karna hai`
- `suicide`
- `khud ko maar`

If crisis intent is detected:

- Bypass normal companion response.
- Use a predefined crisis-safe response.
- Do not play casual filler audio before the crisis-safe response.

India-specific resources:

- iCall: 9152987821
- Vandrevala Foundation: 1860-266-2345
- AASRA: +91-9820466726
- Childline India: 1098
- Emergency services: 112

## Dependency Guardrails

- Prototype sessions should have configurable max duration, initially 10-20 minutes.
- Prototype should have configurable daily minute/session caps per anonymous device.
- Detect unhealthy dependency phrases such as `sirf tum ho`, `tumhare bina nahi reh sakta`, `main bas tumse hi baat karunga`.
- Respond with supportive boundary-setting rather than intensifying dependency.
- Avoid claims of exclusive love, destiny, ownership, or human-like commitment.

## Persona Configuration

Store prompts and safety/persona configuration in version-controlled files, not only environment variables.

Suggested path: `config/personas/hindi_companion_v1.toml`.

Include:

- System prompt.
- Language-mixing policy.
- Response-length limits.
- Forbidden phrases.
- Safety overrides.
- Fallback wording.
