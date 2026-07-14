import asyncio

from app.audio_pipeline import pcm_sine_frame
from app.providers.stt import VoskSTTProvider


class _RecognizerWithPartialOnly:
    def __init__(self, model, sample_rate) -> None:  # noqa: ARG002
        pass

    def SetWords(self, enabled: bool) -> None:  # noqa: ARG002
        pass

    def AcceptWaveform(self, pcm16: bytes) -> bool:  # noqa: ARG002
        return False

    def PartialResult(self) -> str:
        return '{"partial":"mera naam kavya hai"}'

    def FinalResult(self) -> str:
        return '{"text":""}'


class _RecognizerWithFinal:
    def __init__(self, model, sample_rate) -> None:  # noqa: ARG002
        pass

    def SetWords(self, enabled: bool) -> None:  # noqa: ARG002
        pass

    def AcceptWaveform(self, pcm16: bytes) -> bool:  # noqa: ARG002
        return False

    def PartialResult(self) -> str:
        return '{"partial":"mera naam"}'

    def FinalResult(self) -> str:
        return '{"text":"mera naam kavya hai", "result": [{"conf": 0.91}]}'


class _RecognizerWithPauseFinalization:
    def __init__(self, model, sample_rate) -> None:  # noqa: ARG002
        self.calls = 0

    def SetWords(self, enabled: bool) -> None:  # noqa: ARG002
        pass

    def AcceptWaveform(self, pcm16: bytes) -> bool:  # noqa: ARG002
        self.calls += 1
        return self.calls == 1

    def Result(self) -> str:
        return '{"text":"मेरे भाई का नाम रोहन है"}'

    def PartialResult(self) -> str:
        return '{"partial":"वह मुझे अक्सर हंसाता है"}'

    def FinalResult(self) -> str:
        return '{"text":"वह मुझे अक्सर हंसाता है", "result": [{"conf": 0.88}]}'


def _provider(recognizer_type):  # noqa: ANN001
    provider = object.__new__(VoskSTTProvider)
    provider._recognizer_type = recognizer_type
    provider._model = object()
    provider.model_name = "test-vosk"
    return provider


def _frames():
    async def stream():
        yield pcm_sine_frame(duration_ms=30)

    return stream()


def _two_frames():
    async def stream():
        yield pcm_sine_frame(duration_ms=30)
        yield pcm_sine_frame(duration_ms=30)

    return stream()


def test_vosk_uses_best_partial_when_final_result_is_empty() -> None:
    events = asyncio.run(_collect(_provider(_RecognizerWithPartialOnly)))

    assert events[-1].is_final is True
    assert events[-1].text == "mera naam kavya hai"


def test_vosk_prefers_non_empty_final_result() -> None:
    events = asyncio.run(_collect(_provider(_RecognizerWithFinal)))

    assert events[-1].is_final is True
    assert events[-1].text == "mera naam kavya hai"
    assert events[-1].confidence == 0.91


def test_vosk_preserves_segment_before_a_pause_in_the_final_turn() -> None:
    provider = _provider(_RecognizerWithPauseFinalization)
    events = asyncio.run(_collect(provider, frames=_two_frames()))

    assert events[-1].is_final is True
    assert events[-1].text == "मेरे भाई का नाम रोहन है वह मुझे अक्सर हंसाता है"
    assert events[-1].confidence == 0.88


async def _collect(provider, *, frames=None):  # noqa: ANN001
    return [event async for event in provider.stream(frames or _frames(), "hi-IN")]
