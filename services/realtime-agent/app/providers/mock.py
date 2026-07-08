from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator

from app.audio_pipeline import CanonicalAudioFrame
from app.providers.interfaces import (
    LLMMessage,
    LLMProvider,
    LLMToken,
    STTProvider,
    TTSProvider,
    TranscriptEvent,
)


class MockSTTProvider(STTProvider):
    async def stream(
        self,
        audio_frames: AsyncIterator[CanonicalAudioFrame],
        language: str,
    ) -> AsyncIterator[TranscriptEvent]:
        audio_seconds = 0.0
        async for frame in audio_frames:
            audio_seconds += frame.duration_ms / 1000
            if audio_seconds > 0:
                yield TranscriptEvent(
                    text="mock user",
                    is_final=False,
                    confidence=0.99,
                    provider="mock",
                    model="mock",
                    audio_seconds=audio_seconds,
                )
                break
        async for frame in audio_frames:
            audio_seconds += frame.duration_ms / 1000
        yield TranscriptEvent(
            text="mock user audio",
            is_final=True,
            confidence=0.99,
            provider="mock",
            model="mock",
            latency_ms=0,
            audio_seconds=audio_seconds,
        )


class MockLLMProvider(LLMProvider):
    async def stream(
        self,
        messages: list[LLMMessage],
        language: str,
        *,
        max_output_chars: int,
    ) -> AsyncIterator[LLMToken]:
        await asyncio.sleep(0)
        yield LLMToken(text="Haan, main sun raha hoon.", provider="mock", model="mock")

    async def respond(self, prompt: str, language: str) -> str:
        await asyncio.sleep(0)
        return "Haan, main sun raha hoon."


class MockTTSProvider(TTSProvider):
    async def synthesize(self, text: str, language: str) -> AsyncIterator[bytes]:
        # Placeholder bytes exercise the pipeline contract. LiveKit publication
        # is handled by the transport adapter as generated PCM, not real TTS.
        await asyncio.sleep(0)
        yield text.encode("utf-8")
