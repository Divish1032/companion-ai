from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from app.config import Settings, load_provider_routing
from app.providers import KokoroTTSProvider
from app.providers.interfaces import TTSProvider
from app.voice_catalog import load_voice_catalog

READINESS_TEXT = "नमस्ते, आवाज़ की जांच पूरी हुई।"


@dataclass
class TTSReadiness:
    """Warm every published Hindi Kokoro pack without retaining speech output."""

    settings: Settings
    provider_factory: Callable[..., TTSProvider] = KokoroTTSProvider
    status: str = "loading"
    checked_voice_count: int = 0
    failure_kind: str = ""

    async def warm_up(self) -> None:
        if not self._uses_kokoro():
            self.status = "disabled"
            return

        self.status = "loading"
        self.checked_voice_count = 0
        self.failure_kind = ""
        try:
            catalog = load_voice_catalog(self.settings.voice_catalog)
            for voice in catalog.voices.values():
                provider = self.provider_factory(
                    base_url=self.settings.kokoro_base_url,
                    model=self.settings.kokoro_model,
                    voice=voice.kokoro_voice,
                    sample_rate=self.settings.tts_sample_rate,
                    first_audio_timeout_seconds=max(
                        self.settings.kokoro_first_audio_timeout_seconds,
                        self.settings.kokoro_readiness_timeout_seconds,
                    ),
                    total_timeout_seconds=max(
                        self.settings.kokoro_total_timeout_seconds,
                        self.settings.kokoro_readiness_timeout_seconds,
                    ),
                )
                try:
                    frame_count = 0
                    async for frame in provider.synthesize(READINESS_TEXT, catalog.language):
                        if (
                            frame.frame.sample_rate != self.settings.tts_sample_rate
                            or frame.frame.num_channels != 1
                            or len(frame.frame.pcm16) != 960
                        ):
                            raise RuntimeError("invalid_pcm_frame")
                        frame_count += 1
                    if frame_count == 0:
                        raise RuntimeError("empty_audio")
                finally:
                    await provider.close()
                self.checked_voice_count += 1
        except Exception as error:
            self.status = "failed"
            self.failure_kind = type(error).__name__
            return

        self.status = "ready"

    def payload(self) -> dict[str, object]:
        return {
            "status": self.status,
            "tts_provider": "kokoro" if self._uses_kokoro() else "not_kokoro",
            "checked_voice_count": self.checked_voice_count,
            "failure_kind": self.failure_kind,
        }

    def _uses_kokoro(self) -> bool:
        if self.settings.tts_provider:
            return self.settings.tts_provider == "kokoro"
        return load_provider_routing().for_language(self.settings.language).tts == "kokoro"
