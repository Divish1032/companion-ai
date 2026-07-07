from app.providers import ProviderRouting


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
