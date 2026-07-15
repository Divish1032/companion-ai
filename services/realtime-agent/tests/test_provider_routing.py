from app.providers import ProviderRouting
from app.memory_router import route_memory_query
from app.providers.interfaces import LLMMessage
from app.providers.llm import PersonaLLMProvider, SarvamChatLLMProvider
from app.providers.mock import MockLLMProvider, MockSTTProvider, MockTTSProvider
from app.providers.tts import SarvamBulbulTTSProvider, chunk_tts_text
from app.audio_pipeline import pcm_sine_frame
from app.config import Settings
from app.lifecycle import selected_stt_provider_name


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
                        "stt": "sarvam",
                    },
                },
            },
        }
    )

    hindi_route = routing.for_language("hi-IN")
    fallback_route = routing.for_language("te-IN")

    assert hindi_route.stt == "sarvam"
    assert hindi_route.llm == "sarvam"
    assert hindi_route.tts == "sarvam"
    assert fallback_route.stt == "sarvam"


def test_hindi_uses_vosk_by_default_and_sarvam_remains_an_explicit_override() -> None:
    assert selected_stt_provider_name(Settings(stt_provider="", language="hi-IN")) == "vosk"
    assert selected_stt_provider_name(Settings(stt_provider="sarvam", language="hi-IN")) == "sarvam"


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


def test_vague_follow_up_routes_to_episodes_and_open_threads() -> None:
    decision = route_memory_query("Woh interview kaisa raha tha?")

    assert decision.route == "episodic"
    assert decision.max_blocks == 6


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

        def __iter__(self):  # noqa: ANN001
            events = [
                {
                    "choices": [
                        {
                            "delta": {
                                "content": "Namaste, main sun raha hoon.",
                            }
                        }
                    ]
                },
                {
                    "choices": [],
                    "usage": {
                        "prompt_tokens": 11,
                        "completion_tokens": 7,
                        "prompt_tokens_details": {"cached_tokens": 2},
                    },
                },
            ]
            for event in events:
                yield f"data: {json.dumps(event)}\n\n".encode()
            yield b"data: [DONE]\n\n"

    def fake_urlopen(request, timeout):  # noqa: ANN001
        captured["url"] = request.full_url
        captured["timeout"] = timeout
        captured["headers"] = dict(request.header_items())
        captured["payload"] = json.loads(request.data.decode())
        return FakeResponse()

    monkeypatch.setattr("urllib.request.urlopen", fake_urlopen)

    async def scenario() -> list:
        provider = SarvamChatLLMProvider(api_key="sk_test", timeout_seconds=3)
        return [
            token
            async for token in provider.stream(
                [LLMMessage(role="user", content="Namaste")],
                "hi-IN",
                max_output_chars=120,
            )
        ]

    tokens = asyncio.run(scenario())
    assert "".join(token.text for token in tokens) == "Namaste, main sun raha hoon."
    assert tokens[-1].usage_reported is True
    assert (tokens[-1].input_tokens, tokens[-1].cached_input_tokens, tokens[-1].output_tokens) == (
        11,
        2,
        7,
    )
    assert captured["url"] == "https://api.sarvam.ai/v1/chat/completions"
    assert captured["timeout"] == 3
    assert captured["headers"]["Api-subscription-key"] == "sk_test"
    assert captured["headers"]["Authorization"] == "Bearer sk_test"
    assert captured["payload"]["model"] == "sarvam-30b"
    assert captured["payload"]["reasoning_effort"] is None
    assert captured["payload"]["stream"] is True


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


def test_sarvam_tts_streams_linear16_as_canonical_frames() -> None:
    import asyncio

    captured = {}

    class FakeTextToSpeech:
        async def convert_stream(self, **kwargs):  # noqa: ANN003, ANN202
            captured.update(kwargs)
            yield b"\x00\x00" * 700
            yield b"\x00\x00" * 500

    class FakeClient:
        text_to_speech = FakeTextToSpeech()

    async def scenario():
        provider = SarvamBulbulTTSProvider(
            api_key="sk_test",
            timeout_seconds=3,
            client=FakeClient(),
        )
        return [frame async for frame in provider.synthesize("Namaste.", "hi-IN")]

    frames = asyncio.run(scenario())

    assert frames
    assert captured["model"] == "bulbul:v3"
    assert captured["target_language_code"] == "hi-IN"
    assert captured["speaker"] == "shubh"
    assert captured["speech_sample_rate"] == 24000
    assert captured["output_audio_codec"] == "linear16"
    assert frames[0].provider == "sarvam"
    assert frames[0].billed_units == len("Namaste.")
    assert sum(frame.audio_ms for frame in frames) == 50
    assert all(frame.frame.sample_rate == 24000 for frame in frames)
    assert all(frame.frame.num_channels == 1 for frame in frames)
    assert all(len(frame.frame.pcm16) <= 960 for frame in frames)
