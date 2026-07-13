from app.providers import ProviderRouting
from app.memory_router import route_memory_query
from app.providers.interfaces import LLMMessage
from app.providers.llm import PersonaLLMProvider, SarvamChatLLMProvider
from app.providers.mock import MockLLMProvider, MockSTTProvider, MockTTSProvider
from app.providers.tts import SarvamBulbulTTSProvider, chunk_tts_text
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


def test_memory_strategies_are_language_scoped_and_default_safe() -> None:
    routing = ProviderRouting.from_dict(
        {
            "providers": {
                "default": {"stt": "sarvam", "llm": "sarvam", "tts": "sarvam"},
            },
            "memory": {
                "default": {
                    "retrieval": "deterministic",
                    "reranker": "deterministic",
                    "planner": "deterministic",
                },
                "languages": {
                    "hi-IN": {
                        "retrieval": "hybrid_vector",
                        "reranker": "deterministic",
                        "planner": "deterministic",
                    },
                    "future-IN": {
                        "retrieval": "hybrid_vector",
                        "reranker": "qwen3_reranker",
                        "planner": "qwen3_planner",
                    },
                },
            },
        }
    )

    hindi = routing.memory_for_language("hi-IN")
    future = routing.memory_for_language("future-IN")

    assert hindi.retrieval == "hybrid_vector"
    assert hindi.reranker == "deterministic"
    assert future.retrieval == "hybrid_vector"
    assert future.reranker == "qwen3_reranker"
    assert future.planner == "qwen3_planner"


def test_hindi_devanagari_profile_recall_uses_core_profile_route() -> None:
    decision = route_memory_query("मेरा नाम क्या है?")

    assert decision.route == "core_profile"
    assert decision.reason == "profile_or_preference_recall"


def test_ambiguous_topic_turn_does_not_request_memory_lookup() -> None:
    decision = route_memory_query("दुनिया कैसे बनी?")

    assert decision.route == "broad_safe"
    assert decision.max_blocks == 0


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


def test_persona_llm_asks_explicit_memory_receipt_question() -> None:
    import asyncio

    async def scenario() -> str:
        provider = PersonaLLMProvider()
        chunks = [
            token.text
            async for token in provider.stream(
                [
                    LLMMessage(
                        role="system",
                        content=(
                            "[memory_receipt]\n"
                            "After answering naturally, ask at most one short voice-only "
                            "confirmation question.\n"
                            "- (recurring_work_stressor; memory_id=m1) Potential memory: "
                            "User has previously mentioned work stress related to office "
                            "or manager pressure."
                        ),
                    ),
                    LLMMessage(role="user", content="[latest_user] aaj office ka din heavy tha"),
                ],
                "hi-IN",
                max_output_chars=220,
            )
        ]
        return "".join(chunks)

    response = asyncio.run(scenario())

    assert response.endswith("Kya main office/manager pressure wali baat yaad rakhun?")


def test_persona_llm_uses_relationship_admission_without_calling_person_the_user() -> None:
    import asyncio

    async def scenario() -> str:
        provider = PersonaLLMProvider()
        chunks = [
            token.text
            async for token in provider.stream(
                [
                    LLMMessage(
                        role="system",
                        content=(
                            "[turn_admission]\n"
                            "The user said their brother is named रोहन. रोहन is not the user; "
                            "never address the user as रोहन. Acknowledge the relationship naturally, "
                            "without mentioning memory storage."
                        ),
                    ),
                    LLMMessage(role="user", content="मेरे भाई का नाम रोहन है"),
                ],
                "hi-IN",
                max_output_chars=320,
            )
        ]
        return "".join(chunks)

    response = asyncio.run(scenario())

    assert response == "रोहन—अच्छा नाम है। आप दोनों काफ़ी करीब हैं?"
    assert not response.startswith("ठीक है रोहन")


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


def test_tts_chunking_preserves_hindi_hinglish_word_boundaries() -> None:
    text = (
        "Samajh raha hoon. Aaj mood theek nahi hai toh thoda dheere chalte hain aur "
        "ek chhoti si baat batao, sabse zyada heavy kya lag raha hai?"
    )

    chunks = chunk_tts_text(text, max_chars=64)

    assert len(chunks) > 1
    assert "".join(chunks).replace(" ", "") == text.replace(" ", "")
    assert all(not chunk.startswith(" ") and not chunk.endswith(" ") for chunk in chunks)
    assert chunks[0].endswith(".")


def test_sarvam_tts_uses_current_bulbul_request_shape(monkeypatch) -> None:  # noqa: ANN001
    import asyncio
    import base64
    import json

    captured = {}

    class FakeResponse:
        def __enter__(self):  # noqa: ANN001
            return self

        def __exit__(self, exc_type, exc, tb):  # noqa: ANN001
            return False

        def read(self) -> bytes:
            return json.dumps({"audios": [base64.b64encode(_tiny_wav()).decode()]}).encode()

    def fake_urlopen(request, timeout):  # noqa: ANN001
        captured["url"] = request.full_url
        captured["timeout"] = timeout
        captured["headers"] = dict(request.header_items())
        captured["payload"] = json.loads(request.data.decode())
        return FakeResponse()

    monkeypatch.setattr("urllib.request.urlopen", fake_urlopen)

    async def scenario():
        provider = SarvamBulbulTTSProvider(api_key="sk_test", timeout_seconds=3)
        return [frame async for frame in provider.synthesize("Namaste.", "hi-IN")]

    frames = asyncio.run(scenario())

    assert frames
    assert captured["url"] == "https://api.sarvam.ai/text-to-speech"
    assert captured["timeout"] == 3
    assert captured["headers"]["Api-subscription-key"] == "sk_test"
    assert captured["payload"]["model"] == "bulbul:v3"
    assert captured["payload"]["target_language_code"] == "hi-IN"
    assert captured["payload"]["speaker"] == "shubh"
    assert captured["payload"]["speech_sample_rate"] == 24000
    assert captured["payload"]["output_audio_codec"] == "wav"
    assert frames[0].provider == "sarvam"
    assert frames[0].billed_units == len("Namaste.")


def _tiny_wav() -> bytes:
    import io
    import struct
    import wave

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(24000)
        wav_file.writeframes(struct.pack("<" + "h" * 480, *([0] * 480)))
    return buffer.getvalue()
