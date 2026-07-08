from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator

from app.providers.interfaces import LLMProvider, STTProvider, TTSProvider


class MockSTTProvider(STTProvider):
    async def transcribe(self, audio_chunks: AsyncIterator[bytes], language: str) -> str:
        async for _chunk in audio_chunks:
            break
        return "mock user audio"


class MockLLMProvider(LLMProvider):
    async def respond(self, prompt: str, language: str) -> str:
        await asyncio.sleep(0)
        return "Haan, main sun raha hoon."


class MockTTSProvider(TTSProvider):
    async def synthesize(self, text: str, language: str) -> AsyncIterator[bytes]:
        # Placeholder bytes exercise the pipeline contract. LiveKit publication
        # is handled by the transport adapter as generated PCM, not real TTS.
        await asyncio.sleep(0)
        yield text.encode("utf-8")
