from __future__ import annotations

import asyncio
import base64
import io
import json
import time
import urllib.error
import urllib.request
import wave
from collections.abc import AsyncIterator

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

    async def synthesize(self, text: str, language: str) -> AsyncIterator[TTSAudioFrame]:
        started = time.perf_counter()
        for chunk in chunk_tts_text(text):
            wav_audio = await asyncio.to_thread(self._convert, chunk, language)
            frames = _wav_to_canonical_frames(wav_audio, frame_ms=20)
            if not frames:
                continue
            latency_ms = round((time.perf_counter() - started) * 1000)
            chars = len(chunk)
            billed_units = float(chars)
            cost_units = billed_units * self.price_per_10k_chars / 10_000
            audio_ms = sum(frame.duration_ms for frame in frames)
            for index, frame in enumerate(frames):
                yield TTSAudioFrame(
                    frame=frame,
                    provider=self.provider_name,
                    model=self.model_name,
                    text=chunk if index == 0 else "",
                    latency_ms=latency_ms,
                    audio_ms=audio_ms if index == 0 else 0,
                    chars=chars if index == 0 else 0,
                    billed_units=billed_units if index == 0 else 0,
                    cost_units=cost_units if index == 0 else 0,
                )

    def _convert(self, text: str, language: str) -> bytes:
        payload = {
            "text": text,
            "target_language_code": language,
            "speaker": self.speaker,
            "model": self.model_name,
            "speech_sample_rate": self.sample_rate,
            "output_audio_codec": "wav",
        }
        if self.model_name == "bulbul:v3":
            payload["temperature"] = 0.6
            payload["pace"] = 1.0

        request = urllib.request.Request(
            f"{self.base_url}/text-to-speech",
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "api-subscription-key": self.api_key,
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                decoded = json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            raise TTSProviderUnavailable(f"Sarvam TTS request failed: {error}") from error

        audios = decoded.get("audios") if isinstance(decoded, dict) else None
        if not isinstance(audios, list) or not audios or not isinstance(audios[0], str):
            raise TTSProviderUnavailable("Sarvam TTS response did not include audio.")
        try:
            return base64.b64decode(audios[0])
        except ValueError as error:
            raise TTSProviderUnavailable("Sarvam TTS response included invalid base64 audio.") from error


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


def _wav_to_canonical_frames(wav_audio: bytes, *, frame_ms: int) -> list[CanonicalAudioFrame]:
    with wave.open(io.BytesIO(wav_audio), "rb") as wav_file:
        sample_rate = wav_file.getframerate()
        num_channels = wav_file.getnchannels()
        sample_width = wav_file.getsampwidth()
        if sample_width != 2:
            raise TTSProviderUnavailable("Sarvam TTS WAV output was not PCM16.")
        pcm = wav_file.readframes(wav_file.getnframes())

    canonical_pcm = to_mono_pcm16(
        CanonicalAudioFrame(
            pcm16=pcm,
            sample_rate=sample_rate,
            num_channels=num_channels,
            duration_ms=max(round(len(pcm) / (2 * max(num_channels, 1)) / sample_rate * 1000), 1),
        ),
        target_sample_rate=sample_rate,
    )
    samples_per_frame = max(round(sample_rate * frame_ms / 1000), 1)
    bytes_per_frame = samples_per_frame * 2
    frames: list[CanonicalAudioFrame] = []
    for start in range(0, len(canonical_pcm), bytes_per_frame):
        chunk = canonical_pcm[start : start + bytes_per_frame]
        if not chunk:
            continue
        sample_count = len(chunk) // 2
        duration_ms = max(round(sample_count / sample_rate * 1000), 1)
        frames.append(
            CanonicalAudioFrame(
                pcm16=chunk,
                sample_rate=sample_rate,
                num_channels=1,
                duration_ms=duration_ms,
            )
        )
    return frames
