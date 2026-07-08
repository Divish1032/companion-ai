from app.providers import ProviderRouting
from app.providers.interfaces import LLMMessage
from app.providers.llm import SarvamChatLLMProvider
from app.providers.mock import MockLLMProvider, MockSTTProvider, MockTTSProvider
from app.audio_pipeline import pcm_sine_frame


def test_provider_routing_supports_language_override() -> None:
    routing = ProviderRouting.from_dict(
        {
            "providers": {
                "default": {
                    "stt": "sarvam",
                    "llm": "sarvam",
                    "tts": "sarvam",
                },
                "languages": {
                    "hi-IN": {
                        "stt": "vosk",
                    },
                },
            },
        }
    )

    hindi_route = routing.for_language("hi-IN")
    fallback_route = routing.for_language("te-IN")

    assert hindi_route.stt == "vosk"
    assert hindi_route.llm == "sarvam"
    assert hindi_route.tts == "sarvam"
    assert fallback_route.stt == "sarvam"


async def _empty_audio():
    if False:
        yield pcm_sine_frame(duration_ms=30)


def test_mock_providers_are_available_for_skeleton() -> None:
    import asyncio

    async def scenario() -> None:
        stt_events = [event async for event in MockSTTProvider().stream(_empty_audio(), "hi-IN")]
        llm = await MockLLMProvider().respond(stt_events[-1].text, "hi-IN")
        chunks = [chunk async for chunk in MockTTSProvider().synthesize(llm, "hi-IN")]

        assert stt_events[-1].text == "mock user audio"
        assert stt_events[-1].is_final is True
        assert "sun raha" in llm
        assert chunks

    asyncio.run(scenario())


def test_sarvam_llm_uses_voice_safe_request_shape(monkeypatch) -> None:  # noqa: ANN001
    import asyncio
    import json

    captured = {}

    class FakeResponse:
        def __enter__(self):  # noqa: ANN001
            return self

        def __exit__(self, exc_type, exc, tb):  # noqa: ANN001
            return False

        def read(self) -> bytes:
            return json.dumps(
                {
                    "choices": [
                        {
                            "message": {
                                "content": "Namaste, main sun raha hoon.",
                                "role": "assistant",
                            }
                        }
                    ]
                }
            ).encode()

    def fake_urlopen(request, timeout):  # noqa: ANN001
        captured["url"] = request.full_url
        captured["timeout"] = timeout
        captured["headers"] = dict(request.header_items())
        captured["payload"] = json.loads(request.data.decode())
        return FakeResponse()

    monkeypatch.setattr("urllib.request.urlopen", fake_urlopen)

    async def scenario() -> str:
        provider = SarvamChatLLMProvider(api_key="sk_test", timeout_seconds=3)
        chunks = [
            token.text
            async for token in provider.stream(
                [LLMMessage(role="user", content="Namaste")],
                "hi-IN",
                max_output_chars=120,
            )
        ]
        return "".join(chunks)

    assert asyncio.run(scenario()) == "Namaste, main sun raha hoon."
    assert captured["url"] == "https://api.sarvam.ai/v1/chat/completions"
    assert captured["timeout"] == 3
    assert captured["headers"]["Api-subscription-key"] == "sk_test"
    assert captured["headers"]["Authorization"] == "Bearer sk_test"
    assert captured["payload"]["model"] == "sarvam-30b"
    assert captured["payload"]["reasoning_effort"] is None
