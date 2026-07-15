from __future__ import annotations

import asyncio
import json
import time
from base64 import b64encode
from collections.abc import AsyncIterator
from io import BytesIO
from math import ceil
from pathlib import Path
from typing import Any
from wave import open as open_wave

from sarvamai import AsyncSarvamAI

from app.audio_pipeline import CanonicalAudioFrame, to_mono_pcm16
from app.providers.interfaces import STTProvider, TranscriptEvent


class STTProviderUnavailable(RuntimeError):
    pass


class VoskSTTProvider(STTProvider):
    provider_name = "vosk"
    target_sample_rate = 16000

    def __init__(self, *, model_path: str, model_name: str = "vosk-model-small-hi-0.22") -> None:
        if not model_path:
            raise STTProviderUnavailable("AGENT_VOSK_MODEL_PATH is required for Vosk STT.")
        if not Path(model_path).exists():
            raise STTProviderUnavailable(f"Vosk model path does not exist: {model_path}")
        try:
            from vosk import KaldiRecognizer, Model, SetLogLevel
        except Exception as error:  # pragma: no cover - depends on optional runtime package
            raise STTProviderUnavailable("The vosk Python package is not installed.") from error

        SetLogLevel(-1)
        self._recognizer_type = KaldiRecognizer
        self._model = Model(model_path)
        self.model_name = model_name

    async def stream(
        self,
        audio_frames: AsyncIterator[CanonicalAudioFrame],
        language: str,
    ) -> AsyncIterator[TranscriptEvent]:
        started = time.perf_counter()
        recognizer = self._recognizer_type(self._model, self.target_sample_rate)
        recognizer.SetWords(True)
        completed_segments: list[str] = []
        last_partial = ""
        last_emitted = ""
        audio_seconds = 0.0

        async for frame in audio_frames:
            pcm16 = to_mono_pcm16(frame, target_sample_rate=self.target_sample_rate)
            audio_seconds += len(pcm16) / 2 / self.target_sample_rate
            if recognizer.AcceptWaveform(pcm16):
                result = _parse_vosk_json(recognizer.Result())
                text = _clean_text(result.get("text"))
                if text and (not completed_segments or completed_segments[-1] != text):
                    completed_segments.append(text)
                last_partial = ""
                visible_text = " ".join(completed_segments)
                if visible_text and visible_text != last_emitted:
                    last_emitted = visible_text
                    yield self._event(
                        text=visible_text,
                        is_final=False,
                        confidence=_confidence(result),
                        started=started,
                        audio_seconds=audio_seconds,
                    )
            else:
                partial = _clean_text(_parse_vosk_json(recognizer.PartialResult()).get("partial"))
                visible_text = " ".join([*completed_segments, partial]).strip()
                if partial and visible_text != last_emitted:
                    last_partial = partial
                    last_emitted = visible_text
                    yield self._event(
                        text=visible_text,
                        is_final=False,
                        confidence=None,
                        started=started,
                        audio_seconds=audio_seconds,
                    )

        final = _parse_vosk_json(recognizer.FinalResult())
        final_segment = _clean_text(final.get("text"))
        final_parts = [*completed_segments]
        if final_segment and (not final_parts or final_parts[-1] != final_segment):
            final_parts.append(final_segment)
        elif not final_segment and last_partial:
            final_parts.append(last_partial)
        final_text = " ".join(final_parts).strip()
        yield self._event(
            text=final_text,
            is_final=True,
            confidence=_confidence(final),
            started=started,
            audio_seconds=audio_seconds,
        )

    def _event(
        self,
        *,
        text: str,
        is_final: bool,
        confidence: float | None,
        started: float,
        audio_seconds: float,
    ) -> TranscriptEvent:
        return TranscriptEvent(
            text=text,
            is_final=is_final,
            confidence=confidence,
            provider=self.provider_name,
            model=self.model_name,
            latency_ms=round((time.perf_counter() - started) * 1000),
            audio_seconds=round(audio_seconds, 3),
            billed_units=0,
            cost_units=0,
        )


class SarvamSTTProvider(STTProvider):
    provider_name = "sarvam"

    target_sample_rate = 16000

    def __init__(
        self,
        *,
        api_key: str,
        model: str = "saaras:v3",
        mode: str = "codemix",
        chunk_ms: int = 120,
        response_timeout_seconds: float = 5.0,
        price_per_hour: float = 30.0,
        client: Any | None = None,
    ) -> None:
        if not api_key:
            raise STTProviderUnavailable("AGENT_SARVAM_API_KEY is required for Sarvam STT.")
        if model != "saaras:v3":
            raise STTProviderUnavailable(
                "Sarvam streaming STT must use saaras:v3 for this adapter."
            )
        if mode not in {"transcribe", "verbatim", "translit", "codemix"}:
            raise STTProviderUnavailable(f"Unsupported Sarvam STT mode: {mode}")
        if chunk_ms <= 0:
            raise STTProviderUnavailable("AGENT_SARVAM_STT_CHUNK_MS must be positive.")
        if response_timeout_seconds <= 0:
            raise STTProviderUnavailable(
                "AGENT_SARVAM_STT_RESPONSE_TIMEOUT_SECONDS must be positive."
            )

        self.model_name = model
        self.mode = mode
        self.chunk_ms = chunk_ms
        self.response_timeout_seconds = response_timeout_seconds
        self.price_per_hour = price_per_hour
        self.client = client or AsyncSarvamAI(api_subscription_key=api_key)

    async def stream(
        self,
        audio_frames: AsyncIterator[CanonicalAudioFrame],
        language: str,
    ) -> AsyncIterator[TranscriptEvent]:
        started = time.perf_counter()
        audio_seconds = 0.0
        received_segments: list[str] = []
        last_visible = ""

        try:
            async with self.client.speech_to_text_streaming.connect(
                language_code=language,
                model=self.model_name,
                mode=self.mode,
                sample_rate=str(self.target_sample_rate),
                input_audio_codec="wav",
            ) as socket:
                sender = _SarvamAudioSender(
                    socket=socket,
                    audio_frames=audio_frames,
                    sample_rate=self.target_sample_rate,
                    chunk_ms=self.chunk_ms,
                )
                sender_task = sender.start()

                try:
                    while True:
                        response = await self._next_response(socket, sender_task)
                        if response is None:
                            break
                        transcript = _sarvam_transcript(response)
                        if not transcript:
                            continue
                        if not received_segments or received_segments[-1] != transcript:
                            received_segments.append(transcript)
                        visible_text = " ".join(received_segments)
                        is_final = sender_task.done()
                        if not is_final and visible_text != last_visible:
                            last_visible = visible_text
                            yield self._event(
                                text=visible_text,
                                is_final=False,
                                started=started,
                                audio_seconds=sender.audio_seconds,
                            )
                        if is_final:
                            break
                finally:
                    if not sender_task.done():
                        sender_task.cancel()
                    try:
                        await sender_task
                    except asyncio.CancelledError:
                        raise
                    except Exception as error:
                        raise STTProviderUnavailable(
                            f"Sarvam STT audio stream failed: {error}"
                        ) from error
                    audio_seconds = sender.audio_seconds
        except asyncio.CancelledError:
            raise
        except STTProviderUnavailable:
            raise
        except Exception as error:
            raise STTProviderUnavailable(f"Sarvam STT stream failed: {error}") from error

        final_text = " ".join(received_segments).strip()
        yield self._event(
            text=final_text,
            is_final=True,
            started=started,
            audio_seconds=audio_seconds,
        )

    async def _next_response(self, socket: Any, sender_task: "asyncio.Task[None]") -> Any | None:
        receive_task = asyncio.create_task(socket.recv())
        done, _ = await asyncio.wait(
            {receive_task, sender_task},
            return_when=asyncio.FIRST_COMPLETED,
        )
        if receive_task in done:
            return receive_task.result()

        try:
            return await asyncio.wait_for(receive_task, timeout=self.response_timeout_seconds)
        except TimeoutError:
            receive_task.cancel()
            return None

    def _event(
        self,
        *,
        text: str,
        is_final: bool,
        started: float,
        audio_seconds: float,
    ) -> TranscriptEvent:
        billed_units = float(ceil(audio_seconds)) if audio_seconds else 0.0
        return TranscriptEvent(
            text=text,
            is_final=is_final,
            confidence=None,
            provider=self.provider_name,
            model=self.model_name,
            latency_ms=round((time.perf_counter() - started) * 1000),
            audio_seconds=round(audio_seconds, 3),
            billed_units=billed_units if is_final else 0,
            cost_units=(billed_units * self.price_per_hour / 3600) if is_final else 0,
        )


class _SarvamAudioSender:
    def __init__(
        self,
        *,
        socket: Any,
        audio_frames: AsyncIterator[CanonicalAudioFrame],
        sample_rate: int,
        chunk_ms: int,
    ) -> None:
        self.socket = socket
        self.audio_frames = audio_frames
        self.sample_rate = sample_rate
        self.chunk_bytes = max(round(sample_rate * chunk_ms / 1000), 1) * 2
        self.audio_seconds = 0.0

    def start(self) -> "asyncio.Task[None]":
        return asyncio.create_task(self._send(), name="sarvam-stt-audio")

    async def _send(self) -> None:
        pending = bytearray()
        async for frame in self.audio_frames:
            pcm16 = to_mono_pcm16(frame, target_sample_rate=self.sample_rate)
            self.audio_seconds += len(pcm16) / 2 / self.sample_rate
            pending.extend(pcm16)
            while len(pending) >= self.chunk_bytes:
                await self._transcribe(bytes(pending[: self.chunk_bytes]))
                del pending[: self.chunk_bytes]
        if pending:
            await self._transcribe(bytes(pending))
        await self.socket.flush()

    async def _transcribe(self, pcm16: bytes) -> None:
        await self.socket.transcribe(
            b64encode(_wav_bytes(pcm16, self.sample_rate)).decode("ascii"),
            encoding="audio/wav",
            sample_rate=self.sample_rate,
        )


def _wav_bytes(pcm16: bytes, sample_rate: int) -> bytes:
    buffer = BytesIO()
    with open_wave(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(pcm16)
    return buffer.getvalue()


def _sarvam_transcript(response: Any) -> str:
    if getattr(response, "type", "") != "data":
        return ""
    return _clean_text(getattr(getattr(response, "data", None), "transcript", ""))


def _parse_vosk_json(raw: str) -> dict[str, object]:
    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return decoded if isinstance(decoded, dict) else {}


def _clean_text(value: object) -> str:
    return str(value or "").strip()


def _confidence(result: dict[str, object]) -> float | None:
    words = result.get("result")
    if not isinstance(words, list) or not words:
        return None
    confidences = [
        float(item["conf"])
        for item in words
        if isinstance(item, dict) and isinstance(item.get("conf"), int | float)
    ]
    if not confidences:
        return None
    return round(sum(confidences) / len(confidences), 4)
