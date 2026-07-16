from __future__ import annotations

import asyncio
import time
from collections.abc import AsyncIterator
from typing import Any

import httpx

from sarvamai import AsyncSarvamAI
from sarvamai.environment import SarvamAIEnvironment

from app.audio_pipeline import CanonicalAudioFrame, to_mono_pcm16
from app.providers.interfaces import TTSAudioFrame, TTSProvider


class TTSProviderUnavailable(RuntimeError):
    pass


class KokoroTTSProvider(TTSProvider):
    """Kokoro-FastAPI adapter for streamed, raw 24 kHz PCM16 audio."""

    provider_name = "kokoro"

    def __init__(
        self,
        *,
        base_url: str,
        voice: str,
        model: str = "kokoro",
        sample_rate: int = 24000,
        first_audio_timeout_seconds: float = 2.0,
        total_timeout_seconds: float = 12.0,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.voice = voice
        self.model_name = model
        self.sample_rate = sample_rate
        self.first_audio_timeout_seconds = first_audio_timeout_seconds
        self.total_timeout_seconds = total_timeout_seconds
        self.client = client or httpx.AsyncClient(
            timeout=httpx.Timeout(timeout=None, connect=2.0, write=2.0, pool=2.0)
        )

    async def synthesize(self, text: str, language: str) -> AsyncIterator[TTSAudioFrame]:
        started = time.perf_counter()
        emitted_frame = False
        for chunk in chunk_tts_text(text):
            pending = bytearray()
            first_chunk_frame = True
            emitted_chunk_frame = False
            request = {
                "model": self.model_name,
                "input": chunk,
                "voice": self.voice,
                "response_format": "pcm",
                "stream": True,
                "lang_code": "h",
                "speed": 1.0,
                "return_download_link": False,
            }
            try:
                async with asyncio.timeout(self.total_timeout_seconds):
                    async with self.client.stream(
                        "POST",
                        f"{self.base_url}/audio/speech",
                        json=request,
                        headers={"accept": "audio/pcm"},
                    ) as response:
                        response.raise_for_status()
                        stream = response.aiter_bytes()
                        while True:
                            try:
                                if not emitted_chunk_frame:
                                    audio_chunk = await asyncio.wait_for(
                                        anext(stream),
                                        timeout=self.first_audio_timeout_seconds,
                                    )
                                else:
                                    audio_chunk = await anext(stream)
                            except StopAsyncIteration:
                                break
                            if not audio_chunk:
                                continue
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
                                )
                                first_chunk_frame = False
            except asyncio.CancelledError:
                raise
            except (TimeoutError, httpx.HTTPError) as error:
                raise TTSProviderUnavailable(f"Kokoro TTS stream failed: {type(error).__name__}") from error

            if len(pending) % 2:
                raise TTSProviderUnavailable("Kokoro TTS stream returned misaligned PCM16 audio.")
            if pending:
                emitted_frame = True
                emitted_chunk_frame = True
                frame = _final_pcm16_frame(bytes(pending), self.sample_rate)
                yield self._audio_frame(
                    frame,
                    chunk=chunk,
                    first_chunk_frame=first_chunk_frame,
                    started=started,
                )
            if not emitted_chunk_frame:
                raise TTSProviderUnavailable("Kokoro TTS stream returned no audio for a text chunk.")

        if not emitted_frame and text.strip():
            raise TTSProviderUnavailable("Kokoro TTS stream returned no audio.")

    def _audio_frame(
        self,
        frame: CanonicalAudioFrame,
        *,
        chunk: str,
        first_chunk_frame: bool,
        started: float,
    ) -> TTSAudioFrame:
        return TTSAudioFrame(
            frame=frame,
            provider=self.provider_name,
            model="kokoro-82m",
            text=chunk if first_chunk_frame else "",
            latency_ms=round((time.perf_counter() - started) * 1000),
            audio_ms=frame.duration_ms,
            chars=len(chunk) if first_chunk_frame else 0,
            billed_units=0,
            cost_units=0,
        )

    async def close(self) -> None:
        await self.client.aclose()


class FailoverTTSProvider(TTSProvider):
    """Session-scoped primary/fallback TTS without replaying partial speech."""

    def __init__(
        self,
        *,
        primary: TTSProvider,
        fallback: TTSProvider,
        primary_name: str,
        fallback_name: str,
    ) -> None:
        self.primary = primary
        self.fallback = fallback
        self.primary_name = primary_name
        self.fallback_name = fallback_name
        self._active: TTSProvider = primary
        self._fallback_events: list[dict[str, object]] = []

    async def synthesize(self, text: str, language: str) -> AsyncIterator[TTSAudioFrame]:
        if self._active is self.fallback:
            async for frame in self.fallback.synthesize(text, language):
                yield frame
            return

        if _is_latin_only(text):
            self._cut_over(reason="latin_only", audio_started=False)
            async for frame in self.fallback.synthesize(text, language):
                yield frame
            return

        audio_started = False
        try:
            async for frame in self.primary.synthesize(text, language):
                audio_started = True
                yield frame
            return
        except asyncio.CancelledError:
            raise
        except Exception:
            self._cut_over(reason="primary_after_audio" if audio_started else "primary_before_audio", audio_started=audio_started)
            if audio_started:
                return
            try:
                async for frame in self.fallback.synthesize(text, language):
                    yield frame
            except asyncio.CancelledError:
                raise
            except Exception as fallback_error:
                raise TTSProviderUnavailable(
                    f"{self.primary_name} failed before audio and {self.fallback_name} fallback failed: "
                    f"{type(fallback_error).__name__}"
                ) from fallback_error

    def drain_fallback_events(self) -> list[dict[str, object]]:
        events = self._fallback_events
        self._fallback_events = []
        return events

    async def close(self) -> None:
        await self.primary.close()
        if self.fallback is not self.primary:
            await self.fallback.close()

    def _cut_over(self, *, reason: str, audio_started: bool) -> None:
        self._active = self.fallback
        self._fallback_events.append(
            {
                "from": self.primary_name,
                "to": self.fallback_name,
                "reason": reason,
                "audio_started": audio_started,
            }
        )


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
                frame = _final_pcm16_frame(bytes(pending), self.sample_rate)
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


def _is_latin_only(text: str) -> bool:
    has_devanagari = any("\u0900" <= char <= "\u097f" for char in text)
    has_latin = any(("a" <= char.lower() <= "z") for char in text)
    return has_latin and not has_devanagari


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


def _final_pcm16_frame(pcm: bytes, sample_rate: int) -> CanonicalAudioFrame:
    """Return one exact 20 ms frame, padding only the final incomplete PCM."""

    if len(pcm) % 2:
        raise TTSProviderUnavailable("TTS stream returned misaligned PCM16 audio.")
    frame_bytes = _pcm16_frame_bytes(sample_rate, frame_ms=20)
    if len(pcm) > frame_bytes:
        raise TTSProviderUnavailable("TTS stream final PCM exceeded a 20 ms frame.")
    return _pcm16_frame(pcm.ljust(frame_bytes, b"\x00"), sample_rate)


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
