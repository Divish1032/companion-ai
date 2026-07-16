import asyncio

from app.audio_pipeline import pcm_sine_frame
from app.config import Settings
from app.providers.interfaces import TTSAudioFrame
from app.tts_readiness import TTSReadiness


class _ReadyProvider:
    def __init__(self, **_kwargs) -> None:  # noqa: ANN003
        self.closed = False

    async def synthesize(self, _text, _language):  # noqa: ANN001, ANN202
        yield TTSAudioFrame(frame=pcm_sine_frame(duration_ms=20, sample_rate=24000))

    async def close(self) -> None:
        self.closed = True


class _FailingProvider(_ReadyProvider):
    async def synthesize(self, _text, _language):  # noqa: ANN001, ANN202
        raise RuntimeError("not available")
        yield TTSAudioFrame(frame=pcm_sine_frame(duration_ms=20, sample_rate=24000))


def test_kokoro_readiness_warms_every_published_voice() -> None:
    readiness = TTSReadiness(
        Settings(tts_provider="kokoro"),
        provider_factory=_ReadyProvider,
    )

    asyncio.run(readiness.warm_up())

    assert readiness.payload() == {
        "status": "ready",
        "tts_provider": "kokoro",
        "checked_voice_count": 4,
        "failure_kind": "",
    }


def test_kokoro_readiness_fails_closed_without_exposing_error_text() -> None:
    readiness = TTSReadiness(
        Settings(tts_provider="kokoro"),
        provider_factory=_FailingProvider,
    )

    asyncio.run(readiness.warm_up())

    assert readiness.payload() == {
        "status": "failed",
        "tts_provider": "kokoro",
        "checked_voice_count": 0,
        "failure_kind": "RuntimeError",
    }
