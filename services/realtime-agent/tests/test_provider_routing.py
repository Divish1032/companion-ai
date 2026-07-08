from app.providers import ProviderRouting
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
