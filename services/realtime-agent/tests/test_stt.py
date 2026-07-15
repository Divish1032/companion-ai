import asyncio
from types import SimpleNamespace

from app.audio_pipeline import pcm_sine_frame
from app.providers.stt import SarvamSTTProvider, VoskSTTProvider


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


def test_sarvam_streams_saaras_v3_and_keeps_vosk_as_a_separate_adapter() -> None:
    class FakeSocket:
        def __init__(self) -> None:
            self.sent = []
            self.responses = asyncio.Queue()

        async def transcribe(self, audio, encoding, sample_rate) -> None:  # noqa: ANN001
            self.sent.append((audio, encoding, sample_rate))
            await self.responses.put(
                SimpleNamespace(
                    type="data",
                    data=SimpleNamespace(
                        transcript="नमस्ते", metrics=SimpleNamespace(audio_duration=0.03)
                    ),
                )
            )

        async def flush(self) -> None:
            return None

        async def recv(self):  # noqa: ANN201
            return await self.responses.get()

    class FakeConnection:
        def __init__(self, socket) -> None:  # noqa: ANN001
            self.socket = socket

        async def __aenter__(self):  # noqa: ANN201
            return self.socket

        async def __aexit__(self, exc_type, exc, tb):  # noqa: ANN001
            return False

    class FakeStreamingClient:
        def __init__(self, socket) -> None:  # noqa: ANN001
            self.socket = socket
            self.connect_kwargs = {}

        def connect(self, **kwargs):  # noqa: ANN003, ANN201
            self.connect_kwargs = kwargs
            return FakeConnection(self.socket)

    socket = FakeSocket()
    streaming_client = FakeStreamingClient(socket)
    client = SimpleNamespace(speech_to_text_streaming=streaming_client)
    provider = SarvamSTTProvider(api_key="sk_test", client=client, chunk_ms=30)

    events = asyncio.run(_collect(provider))

    assert streaming_client.connect_kwargs == {
        "language_code": "hi-IN",
        "model": "saaras:v3",
        "mode": "codemix",
        "sample_rate": "16000",
        "input_audio_codec": "wav",
    }
    assert socket.sent and socket.sent[0][1:] == ("audio/wav", 16000)
    assert [event.text for event in events] == ["नमस्ते"]
    assert events[-1].is_final is True
    assert events[-1].provider == "sarvam"
    assert events[-1].model == "saaras:v3"


async def _collect(provider, *, frames=None):  # noqa: ANN001
    return [event async for event in provider.stream(frames or _frames(), "hi-IN")]
