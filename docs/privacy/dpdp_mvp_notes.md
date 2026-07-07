# DPDP MVP Notes

Date: 2026-07-07

Sprint: Sprint -1 Validation Gates

Scope:

- Lock MVP consent and privacy notes needed before real-user field testing.
- Keep scope limited to MVP voice-only behavior.
- Do not expand into later auth or cloud-history work.

## MVP Privacy Position

For MVP:

- no auth
- no text input
- no video or avatar
- no raw audio storage
- transcript history stored locally on device only
- backend and AI providers process audio and transcript to generate responses

This document is a working Sprint -1 note, not a full legal opinion.

## Consent Copy Draft

Use this as the first-session consent baseline:

```text
Your voice and transcript are sent to our server and AI providers to understand and respond.
We do not store raw audio in this MVP. Chat history is saved on this device.
You can clear chat history anytime.
Tap Agree to continue.
```

Implementation notes:

- show before or during first microphone or session start
- store acceptance locally with timestamp and consent-copy version
- require renewed acceptance if the copy changes materially

Suggested metadata to store locally:

- consent version
- accepted timestamp
- app build version
- anonymous device id

## Data Handling Summary

Data handled in MVP:

- microphone audio during active session
- transcript text generated from that audio
- assistant response text
- assistant audio generated for playback
- anonymous device id
- session ids
- latency and cost telemetry

Planned handling rules:

- do not store raw microphone audio after realtime processing
- keep transcript history on device only for MVP
- avoid logging full transcript text in production logs by default
- prefer redacted or aggregate metrics for observability
- use TLS for backend API traffic
- keep provider integrations behind interfaces so processor disclosure can stay explicit

Unknowns that still need implementation proof later:

- exact local transcript encryption method before real-user field testing
- exact retention and deletion behavior for backend operational logs

## Processor Disclosure Placeholder

Current expected processors and roles:

| Processor | Role | Data categories sent | Status | Public policy reference |
| --- | --- | --- | --- | --- |
| Companion AI backend | primary service operator | session audio in transit, transcript text, response text, metrics | required for MVP | internal docs and future public privacy notice |
| Sarvam AI (Axonwise Private Limited) | STT, TTS, and possibly LLM processor | audio, transcript text, response text needed for active turn processing | expected primary provider, subject to final integration choice | https://www.sarvam.ai/privacy-policy and https://www.sarvam.ai/terms-of-service |
| LiveKit self-hosted deployment | realtime transport processor controlled by us | live audio transport metadata and media in transit | expected for MVP | self-hosted infra under our control |

Notes:

- Replace this table with exact deployed processors before any field test.
- If the first LLM provider differs from Sarvam, update the table before release.
- If TURN, hosting, monitoring, or crash-reporting vendors receive personal data, they must be added before field testing.

## Sarvam Public Legal Notes

Public Sarvam pages reviewed on 2026-07-07:

- Privacy policy: https://www.sarvam.ai/privacy-policy
- Terms of service: https://www.sarvam.ai/terms-of-service

What is known from those public pages:

- Sarvam publicly states that Axonwise Private Limited is the data fiduciary for its own offerings.
- Sarvam terms publicly describe customer content ownership and a limited service-use license.
- Sarvam terms mention a Data Processing Addendum and say Sarvam acts as processor where applicable.
- Sarvam public legal pages are current enough to use as disclosure placeholders, but they are not a substitute for our own product notice.

What remains to validate before real-user testing:

- exact Sarvam subprocessors if relevant to our deployment
- whether Sarvam offers any account-level data retention controls we must configure
- whether any provider opt-out or no-training setting is available and should be enabled

## MVP User Rights and Controls

Minimum user-facing controls before field testing:

- clear chat history on device
- visible consent copy
- minimal contact or grievance route in app settings or consent screen
- ability to stop a live session

Operational interpretation for MVP:

- clear history acts as local erasure for transcript storage on device
- deleting the app may reset anonymous device identity and local history
- because there is no auth, cross-device recovery is not available

## Field-Test Privacy Checklist

All items below should be true before real-user field testing:

- consent screen is implemented and acceptance is stored locally
- consent copy versioning exists
- chat history clear action works
- local transcript storage is encrypted, or field test is restricted to scripted non-sensitive conversations
- no raw audio is stored anywhere in app or backend
- backend logs are reviewed to ensure transcripts are not logged by default
- processor list is updated with exact deployed vendors
- contact or grievance email is visible in product copy
- crisis-safe flow is implemented before TTS
- privacy note explicitly states that backend and AI providers process voice and transcript
- test plan avoids collecting sensitive conversations until storage protections are verified

## Minimal Contact Placeholder

Until product copy is finalized, reserve a placeholder such as:

```text
Questions or privacy concerns? Contact: [to be assigned before field testing]
```

This placeholder must be replaced before any external field test.

## Decision Impact

Sprint -1 outcome:

- MVP privacy direction is now explicit enough to guide Sprint 1 consent UX and local-storage decisions.
- Field testing remains blocked until transcript encryption or equivalent scripted-test restriction is in place.
- Processor disclosure remains a required pre-field-test checklist item, not an optional polish task.

