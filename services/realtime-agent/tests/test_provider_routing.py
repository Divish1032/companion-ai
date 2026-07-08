from app.providers import ProviderRouting
from app.providers.mock import MockLLMProvider, MockSTTProvider, MockTTSProvider


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
        yield b""


def test_mock_providers_are_available_for_skeleton() -> None:
    import asyncio

    async def scenario() -> None:
        stt = await MockSTTProvider().transcribe(_empty_audio(), "hi-IN")
        llm = await MockLLMProvider().respond(stt, "hi-IN")
        chunks = [chunk async for chunk in MockTTSProvider().synthesize(llm, "hi-IN")]

        assert stt == "mock user audio"
        assert "sun raha" in llm
        assert chunks

    asyncio.run(scenario())
