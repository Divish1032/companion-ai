from abc import ABC, abstractmethod
from collections.abc import AsyncIterator


class STTProvider(ABC):
    @abstractmethod
    async def transcribe(self, audio_chunks: AsyncIterator[bytes], language: str) -> str:
        raise NotImplementedError


class LLMProvider(ABC):
    @abstractmethod
    async def respond(self, prompt: str, language: str) -> str:
        raise NotImplementedError


class TTSProvider(ABC):
    @abstractmethod
    async def synthesize(self, text: str, language: str) -> AsyncIterator[bytes]:
        raise NotImplementedError
