from __future__ import annotations

import asyncio
import time
from collections.abc import AsyncIterator
from typing import Any

from sarvamai import AsyncSarvamAI
from sarvamai.environment import SarvamAIEnvironment

from app.audio_pipeline import CanonicalAudioFrame, to_mono_pcm16
from app.providers.interfaces import TTSAudioFrame, TTSProvider


class TTSProviderUnavailable(RuntimeError):
    pass


class SarvamBulbulTTSProvider(TTSProvider):
    provider_name = "sarvam"

    def __init__(
        self,
        *,
        api_key: str,
        model: str = "bulbul:v3",
        base_url: str = "https://api.sarvam.ai",
        speaker: str = "shubh",
        sample_rate: int = 24000,
        timeout_seconds: float = 12.0,
        price_per_10k_chars: float = 30.0,
        client: Any | None = None,
    ) -> None:
        if not api_key:
            raise TTSProviderUnavailable("AGENT_SARVAM_API_KEY is required for Sarvam TTS.")
        self.api_key = api_key
        self.model_name = model
        self.base_url = base_url.rstrip("/")
        self.speaker = speaker
        self.sample_rate = sample_rate
        self.timeout_seconds = timeout_seconds
        self.price_per_10k_chars = price_per_10k_chars
        self.client = client or AsyncSarvamAI(
            api_subscription_key=api_key,
            environment=_sarvam_environment(self.base_url),
            timeout=timeout_seconds,
        )

    async def synthesize(self, text: str, language: str) -> AsyncIterator[TTSAudioFrame]:
        started = time.perf_counter()
        emitted_frame = False
        for chunk in chunk_tts_text(text):
            chars = len(chunk)
            billed_units = float(chars)
            cost_units = billed_units * self.price_per_10k_chars / 10_000
            pending = bytearray()
            first_chunk_frame = True
            emitted_chunk_frame = False
            try:
                request = {
                    "text": chunk,
                    "target_language_code": language,
                    "speaker": self.speaker,
                    "model": self.model_name,
                    "speech_sample_rate": self.sample_rate,
                    "output_audio_codec": "linear16",
                    "pace": 1.0,
                }
                if self.model_name == "bulbul:v3":
                    request["temperature"] = 0.6
                stream = self.client.text_to_speech.convert_stream(**request)
                async for audio_chunk in stream:
                    pending.extend(audio_chunk)
                    while len(pending) >= _pcm16_frame_bytes(self.sample_rate, frame_ms=20):
                        frame = _take_pcm16_frame(pending, self.sample_rate, frame_ms=20)
                        emitted_frame = True
                        emitted_chunk_frame = True
                        yield self._audio_frame(
                            frame,
                            chunk=chunk,
                            first_chunk_frame=first_chunk_frame,
                            started=started,
                            chars=chars,
                            billed_units=billed_units,
                            cost_units=cost_units,
                        )
                        first_chunk_frame = False
            except asyncio.CancelledError:
                raise
            except Exception as error:
                raise TTSProviderUnavailable(f"Sarvam TTS stream failed: {error}") from error

            if pending:
                frame = _pcm16_frame(bytes(pending), self.sample_rate)
                emitted_frame = True
                emitted_chunk_frame = True
                yield TTSAudioFrame(
                    frame=frame,
                    provider=self.provider_name,
                    model=self.model_name,
                    text=chunk if first_chunk_frame else "",
                    latency_ms=round((time.perf_counter() - started) * 1000),
                    audio_ms=frame.duration_ms,
                    chars=chars if first_chunk_frame else 0,
                    billed_units=billed_units if first_chunk_frame else 0,
                    cost_units=cost_units if first_chunk_frame else 0,
                )
            if not emitted_chunk_frame:
                raise TTSProviderUnavailable("Sarvam TTS stream returned no audio for a text chunk.")

        if not emitted_frame and text.strip():
            raise TTSProviderUnavailable("Sarvam TTS stream returned no audio.")

    def _audio_frame(
        self,
        frame: CanonicalAudioFrame,
        *,
        chunk: str,
        first_chunk_frame: bool,
        started: float,
        chars: int,
        billed_units: float,
        cost_units: float,
    ) -> TTSAudioFrame:
        return TTSAudioFrame(
            frame=frame,
            provider=self.provider_name,
            model=self.model_name,
            text=chunk if first_chunk_frame else "",
            latency_ms=round((time.perf_counter() - started) * 1000),
            audio_ms=frame.duration_ms,
            chars=chars if first_chunk_frame else 0,
            billed_units=billed_units if first_chunk_frame else 0,
            cost_units=cost_units if first_chunk_frame else 0,
        )


def chunk_tts_text(text: str, *, max_chars: int = 300) -> list[str]:
    cleaned = " ".join(text.split())
    if not cleaned:
        return []

    chunks: list[str] = []
    remaining = cleaned
    while remaining:
        if len(remaining) <= max_chars:
            chunks.append(remaining)
            break
        boundary = _safe_boundary(remaining, max_chars)
        chunks.append(remaining[:boundary].strip())
        remaining = remaining[boundary:].strip()
    return chunks


def _safe_boundary(text: str, max_chars: int) -> int:
    punctuation = max(text.rfind(mark, 0, max_chars + 1) for mark in (".", "?", "!", "।", ";"))
    if punctuation >= min(16, max_chars // 3):
        return punctuation + 1

    phrase_markers = (", ", " aur ", " lekin ", " par ", " toh ", " phir ", " matlab ")
    marker_positions = [text.rfind(marker, 0, max_chars + 1) for marker in phrase_markers]
    phrase = max(marker_positions)
    if phrase >= max_chars // 2:
        return phrase + 1

    whitespace = text.rfind(" ", 0, max_chars + 1)
    if whitespace >= max_chars // 2:
        return whitespace
    return max_chars


def _sarvam_environment(base_url: str) -> SarvamAIEnvironment:
    websocket_url = base_url.replace("https://", "wss://", 1).replace("http://", "ws://", 1)
    return SarvamAIEnvironment(base=base_url, production=websocket_url)


def _pcm16_frame_bytes(sample_rate: int, *, frame_ms: int) -> int:
    return max(round(sample_rate * frame_ms / 1000), 1) * 2


def _take_pcm16_frame(
    pending: bytearray,
    sample_rate: int,
    *,
    frame_ms: int,
) -> CanonicalAudioFrame:
    byte_count = _pcm16_frame_bytes(sample_rate, frame_ms=frame_ms)
    pcm = bytes(pending[:byte_count])
    del pending[:byte_count]
    return _pcm16_frame(pcm, sample_rate)


def _pcm16_frame(pcm: bytes, sample_rate: int) -> CanonicalAudioFrame:
    if len(pcm) % 2:
        raise TTSProviderUnavailable("Sarvam TTS stream returned misaligned PCM16 audio.")
    canonical = to_mono_pcm16(
        CanonicalAudioFrame(
            pcm16=pcm,
            sample_rate=sample_rate,
            num_channels=1,
            duration_ms=max(round((len(pcm) // 2) / sample_rate * 1000), 1),
        ),
        target_sample_rate=sample_rate,
    )
    return CanonicalAudioFrame(
        pcm16=canonical,
        sample_rate=sample_rate,
        num_channels=1,
        duration_ms=max(round((len(canonical) // 2) / sample_rate * 1000), 1),
    )
