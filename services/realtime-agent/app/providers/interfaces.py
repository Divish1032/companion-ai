from abc import ABC, abstractmethod
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Literal

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


@dataclass(frozen=True)
class LLMMessage:
    role: Literal["system", "user", "assistant"]
    content: str


@dataclass(frozen=True)
class LLMToken:
    text: str
    provider: str = ""
    model: str = ""
    latency_ms: int = 0
    billed_units: float = 0
    cost_units: float = 0
    input_tokens: int = 0
    cached_input_tokens: int = 0
    output_tokens: int = 0
    usage_reported: bool = False


@dataclass(frozen=True)
class TTSAudioFrame:
    frame: CanonicalAudioFrame
    provider: str = ""
    model: str = ""
    text: str = ""
    latency_ms: int = 0
    audio_ms: int = 0
    chars: int = 0
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
    async def stream(
        self,
        messages: list[LLMMessage],
        language: str,
        *,
        max_output_chars: int,
    ) -> AsyncIterator[LLMToken]:
        raise NotImplementedError

    async def respond(self, prompt: str, language: str) -> str:
        chunks = [
            token.text
            async for token in self.stream(
                [LLMMessage(role="user", content=prompt)],
                language,
                max_output_chars=240,
            )
        ]
        return "".join(chunks)


class TTSProvider(ABC):
    @abstractmethod
    async def synthesize(self, text: str, language: str) -> AsyncIterator[TTSAudioFrame]:
        raise NotImplementedError
