from abc import ABC, abstractmethod
from collections.abc import AsyncIterator
from dataclasses import dataclass

from app.audio_pipeline import CanonicalAudioFrame


@dataclass(frozen=True)
class TranscriptEvent:
    text: str
    is_final: bool
    confidence: float | None = None
    provider: str = ""
    model: str = ""
    latency_ms: int = 0
    audio_seconds: float = 0
    billed_units: float = 0
    cost_units: float = 0


class STTProvider(ABC):
    @abstractmethod
    async def stream(
        self,
        audio_frames: AsyncIterator[CanonicalAudioFrame],
        language: str,
    ) -> AsyncIterator[TranscriptEvent]:
        raise NotImplementedError


class LLMProvider(ABC):
    @abstractmethod
    async def respond(self, prompt: str, language: str) -> str:
        raise NotImplementedError


class TTSProvider(ABC):
    @abstractmethod
    async def synthesize(self, text: str, language: str) -> AsyncIterator[bytes]:
        raise NotImplementedError
