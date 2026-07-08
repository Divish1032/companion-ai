from __future__ import annotations

import json
import time
from collections.abc import AsyncIterator
from pathlib import Path

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
        last_partial = ""
        audio_seconds = 0.0

        async for frame in audio_frames:
            pcm16 = to_mono_pcm16(frame, target_sample_rate=self.target_sample_rate)
            audio_seconds += len(pcm16) / 2 / self.target_sample_rate
            if recognizer.AcceptWaveform(pcm16):
                result = _parse_vosk_json(recognizer.Result())
                text = _clean_text(result.get("text"))
                if text and text != last_partial:
                    last_partial = text
                    yield self._event(
                        text=text,
                        is_final=False,
                        confidence=_confidence(result),
                        started=started,
                        audio_seconds=audio_seconds,
                    )
            else:
                partial = _clean_text(_parse_vosk_json(recognizer.PartialResult()).get("partial"))
                if partial and partial != last_partial:
                    last_partial = partial
                    yield self._event(
                        text=partial,
                        is_final=False,
                        confidence=None,
                        started=started,
                        audio_seconds=audio_seconds,
                    )

        final = _parse_vosk_json(recognizer.FinalResult())
        yield self._event(
            text=_clean_text(final.get("text")),
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

    async def stream(
        self,
        audio_frames: AsyncIterator[CanonicalAudioFrame],
        language: str,
    ) -> AsyncIterator[TranscriptEvent]:
        raise STTProviderUnavailable("Sarvam STT adapter is scaffolded for future fallback use.")
        yield  # pragma: no cover


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
