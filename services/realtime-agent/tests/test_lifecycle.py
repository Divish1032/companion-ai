import asyncio
import json
import time

from app.config import Settings
from app.audio_pipeline import (
    CanonicalAudioFrame,
    EndpointEvent,
    pcm_silence_frame,
    pcm_sine_frame,
)
from app.lifecycle import (
    AgentAssignment,
    MemoryAgentTransport,
    RealtimeAgentSession,
    _looks_like_question_echo,
    _live_data_unavailable_response,
    _memory_admission_hint,
    _render_memory_directive,
    _sanitize_llm_output,
    _wait_until_started,
)

from app.providers.interfaces import (
    LLMMessage,
    LLMProvider,
    LLMToken,
    STTProvider,
    TTSAudioFrame,
    TTSProvider,
    TranscriptEvent,
)
from app.providers.mock import MockSTTProvider


def test_query_echo_guard_only_matches_question_restatement() -> None:
    assert _looks_like_question_echo("मेरा नाम क्या है", "मेरा नाम क्या है?")
    assert not _looks_like_question_echo("मेरा नाम क्या है", "मुझे आपका नाम अभी पता नहीं है।")
    assert not _looks_like_question_echo("दुनिया कैसे बनी", "यह एक बड़ा वैज्ञानिक सवाल है।")


def test_memory_confirmation_is_deterministic_and_low_risk_admission_uses_llm() -> None:
    confirmation = _render_memory_directive(
        {
            "response_directive": "confirmation",
            "pending_candidate": {
                "state_key": "user.routine.morning.walk",
                "value": {"text": "walk"},
            },
        }
    )
    admission_context = {
        "response_directive": "setting_ack",
        "state_facts": [
            {
                "state_key": "user.relationship.brother.रोहन",
                "value": {"text": "रोहन"},
            }
        ],
    }
    acknowledgement = _render_memory_directive(admission_context)
    admission = _memory_admission_hint(admission_context)

    assert confirmation == "आप रोज सुबह टहलते हैं। क्या मैं यह याद रखूँ? टहलने के बाद आपको कैसा लगता है?"
    assert acknowledgement is None
    assert admission == {
        "kind": "relationship",
        "relationship_role": "brother",
        "person_name": "रोहन",
    }


def test_live_weather_is_not_fabricated_without_a_live_data_tool() -> None:
    assert _live_data_unavailable_response("आज मौसम कैसा है?") == (
        "मेरे पास लाइव मौसम की जानकारी नहीं है, इसलिए मैं अंदाज़ा नहीं लगाना चाहता।"
    )
    assert _live_data_unavailable_response("आज मेरा मन उदास है") is None


def test_agent_emits_state_sequence_and_filler_before_fake_audio() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        await transport.activity.put("client_fake_turn")
        await _wait_for_events(transport, minimum=6)
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    states = [event.get("state") for event in events if event["type"] == "session_state"]
    filler_states = [event.get("state") for event in events if event["type"] == "filler_audio"]

    assert states[:4] == ["listening", "thinking", "speaking", "listening"]
    assert filler_states == ["started", "stopped"]
    assert transport.audio_publications == 1
    assert transport.disconnected is True
    assert all("sequence" in event for event in events)
    assert any(str(event.get("turn_id", "")).endswith("turn:0001") for event in events)


def test_cancellation_primitive_cancels_current_turn() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
    )

    async def scenario() -> bool:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        await transport.activity.put("client_fake_turn")
        await _wait_for_state(transport, "thinking")
        cancelled = session.cancel_current_turn()
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        return cancelled

    assert asyncio.run(scenario()) is True


def test_safety_override_runs_before_fake_audio() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(
            recent_context=[
                {
                    "role": "user",
                    "text": "suicide",
                    "turn_id": "turn_1",
                    "created_at_ms": 1,
                }
            ]
        ),
        settings=_settings(),
        transport=transport,
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        await transport.activity.put("client_fake_turn")
        await _wait_for_events(transport, minimum=4)
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assert [event["type"] for event in events].count("filler_audio") == 0
    assert any(event.get("safety_reason") == "crisis_keyword" for event in events)
    assert transport.audio_publications == 1


def test_barge_in_during_fake_ai_speech_cancels_speaking_state() -> None:
    transport = MemoryAgentTransport(audio_publish_delay_seconds=1)
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=MockSTTProvider(),
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        await transport.activity.put("client_fake_turn")
        await _wait_for_state(transport, "speaking")
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(20):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "barge_in")
        await _wait_for_event_type(transport, "endpoint_commit")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assert any(
        event["type"] == "barge_in"
        and event.get("cancelled") is True
        and event.get("stage") == "during_speaking"
        for event in events
    )
    assert any(event["type"] == "endpoint_commit" for event in events)
    assert any(
        event["type"] == "session_state" and event.get("state") == "listening" for event in events
    )


def test_audio_endpoint_runs_stt_and_emits_transcript_metrics() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=MockSTTProvider(),
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "transcript_final")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    reliable = [_decode(event) for event in transport.events]
    lossy = [_decode(event) for event in transport.lossy_events]
    final = next(event for event in reliable if event["type"] == "transcript_final")

    assert any(event["type"] == "transcript_partial" for event in lossy)
    assert final["text"] == "mock user audio"
    assert final["status"] == "final"
    assert final["audio_seconds"] > 0
    assert final["billed_units"] == 0
    assert final["cost_units"] == 0
    assert final["latency_ms"] >= 0


def test_final_transcript_streams_assistant_response() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=StaticSTTProvider("namaste mera mood theek nahi hai"),
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "assistant_transcript_final")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    reliable = [_decode(event) for event in transport.events]
    lossy = [_decode(event) for event in transport.lossy_events]
    assistant = next(event for event in reliable if event["type"] == "assistant_transcript_final")

    assert any(event["type"] == "assistant_transcript_partial" for event in lossy)
    assert "Samajh raha hoon" in str(assistant["text"])
    assert assistant["provider"] == "persona_local"
    assert assistant["status"] == "final"
    assert assistant["cost_units"] == 0


def test_final_transcript_synthesizes_tts_audio_and_metrics() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=StaticSTTProvider("namaste"),
        tts_provider=StaticTTSProvider(),
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "tts_metrics")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    metrics = next(event for event in events if event["type"] == "tts_metrics")

    assert transport.audio_publications == 2
    assert metrics["provider"] == "test-tts"
    assert metrics["chars"] > 0
    assert metrics["billed_units"] > 0
    assert metrics["cost_units"] > 0
    assert metrics["first_audio_ms"] >= 0


def test_llm_error_produces_graceful_fallback() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=StaticSTTProvider("namaste"),
        llm_provider=FailingLLMProvider(),
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "assistant_transcript_final")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assistant = next(event for event in events if event["type"] == "assistant_transcript_final")
    assert "jawab dene mein dikkat" in str(assistant["text"])
    assert assistant["provider"] == "persona_local"


def test_overlong_llm_output_is_clipped_before_final_response() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=StaticSTTProvider("namaste"),
        llm_provider=LongLLMProvider(),
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "assistant_transcript_final")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assistant = next(event for event in events if event["type"] == "assistant_transcript_final")
    assert len(str(assistant["text"])) <= 320
    assert assistant["clipped"] is True


def test_crisis_final_transcript_uses_safety_response_without_llm() -> None:
    transport = MemoryAgentTransport()
    llm = CountingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=StaticSTTProvider("main mar jaana chahta hoon"),
        llm_provider=llm,
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "assistant_transcript_final")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assistant = next(event for event in events if event["type"] == "assistant_transcript_final")
    assert assistant["status"] == "safety_override"
    assert assistant["safety_reason"] == "crisis_keyword"
    assert "112" in str(assistant["text"])
    assert llm.calls == 0
    assert transport.audio_publications == 0


def test_crisis_final_transcript_uses_safety_response_for_devanagari_input() -> None:
    transport = MemoryAgentTransport()
    llm = CountingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=StaticSTTProvider("मैं मर जाना चाहता हूं"),
        llm_provider=llm,
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "assistant_transcript_final")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assistant = next(event for event in events if event["type"] == "assistant_transcript_final")
    assert assistant["status"] == "safety_override"
    assert assistant["safety_reason"] == "crisis_keyword"
    assert "112" in str(assistant["text"])
    assert llm.calls == 0


def test_previous_session_memory_reaches_llm_response_path() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(
            recent_context={
                "recent_turns": [],
                "memory_blocks": [
                    {
                        "memory_id": "memory_preferred_name",
                        "kind": "stable_fact",
                        "label": "preferred_name",
                        "content": "User prefers to be called Rahul.",
                        "source_turn_ids": ["old_turn"],
                        "source_role": "user",
                        "transcript_status": "final",
                        "stt_confidence": 0.99,
                        "created_at_ms": 1,
                        "updated_at_ms": 2,
                        "last_used_at_ms": None,
                        "confidence_score": 0.8,
                        "importance_score": 0.9,
                    }
                ],
            }
        ),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=StaticSTTProvider("mera naam kya yaad hai"),
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "assistant_transcript_final")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assistant = next(event for event in events if event["type"] == "assistant_transcript_final")
    assert "Rahul" in str(assistant["text"])


def test_crisis_input_is_not_overridden_by_memory_context() -> None:
    transport = MemoryAgentTransport()
    llm = CountingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(
            recent_context={
                "recent_turns": [],
                "memory_blocks": [
                    {
                        "memory_id": "memory_preference",
                        "kind": "stable_fact",
                        "label": "safe_preference",
                        "content": "User explicitly said: mujhe jokes pasand hai.",
                        "source_turn_ids": ["old_turn"],
                        "source_role": "user",
                        "transcript_status": "final",
                        "stt_confidence": 0.99,
                        "created_at_ms": 1,
                        "updated_at_ms": 2,
                        "last_used_at_ms": None,
                        "confidence_score": 0.8,
                        "importance_score": 0.7,
                    }
                ],
            }
        ),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=StaticSTTProvider("main mar jaana chahta hoon"),
        llm_provider=llm,
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "assistant_transcript_final")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assistant = next(event for event in events if event["type"] == "assistant_transcript_final")
    assert assistant["status"] == "safety_override"
    assert assistant["safety_reason"] == "crisis_keyword"
    assert llm.calls == 0


def test_barge_in_stops_tts_audio_with_fade_path() -> None:
    transport = MemoryAgentTransport(audio_publish_delay_seconds=1)
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=StaticSTTProvider("namaste"),
        tts_provider=SlowTTSProvider(),
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_state(transport, "speaking")
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        await _wait_for_event_type(transport, "barge_in")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assert any(
        event["type"] == "barge_in"
        and event.get("cancelled") is True
        and event.get("stage") == "during_speaking"
        for event in events
    )
    assert transport.audio_publications >= 1


def test_llm_context_preserves_assistant_roles_and_updates_in_session_history() -> None:
    llm = RecordingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(
            recent_context=[
                {
                    "role": "user",
                    "text": "pehla user turn",
                    "turn_id": "turn_1",
                    "created_at_ms": 1,
                },
                {
                    "role": "assistant",
                    "text": "pehla assistant reply",
                    "turn_id": "turn_1",
                    "created_at_ms": 2,
                },
                {
                    "role": "ai",
                    "text": "legacy ai reply",
                    "turn_id": "turn_2",
                    "created_at_ms": 3,
                },
            ]
        ),
        settings=_settings(),
        transport=MemoryAgentTransport(),
        llm_provider=llm,
    )

    async def scenario() -> None:
        await session._respond_to_final_transcript("session_test:turn:0003", "naya user turn")
        await session._respond_to_final_transcript("session_test:turn:0004", "dusra user turn")

    asyncio.run(scenario())

    first_roles = [(message.role, message.content) for message in llm.calls[0]]
    second_roles = [(message.role, message.content) for message in llm.calls[1]]

    assert ("assistant", "pehla assistant reply") in first_roles
    assert ("assistant", "legacy ai reply") in first_roles
    assert ("assistant", "recorded reply") in second_roles
    assert second_roles[-1] == ("user", "dusra user turn")


def test_query_time_memory_lookup_response_reaches_llm_context(capsys) -> None:  # noqa: ANN001
    transport = MemoryAgentTransport()
    llm = RecordingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
        llm_provider=llm,
    )

    async def scenario() -> None:
        task = asyncio.create_task(
            session._respond_to_final_transcript("session_test:turn:0005", "office bad day tha")
        )
        request = await _wait_for_decoded_event_type(transport, "memory_lookup_request")
        assert request["memory_retrieval_strategy"] == "hybrid_vector"
        assert request["memory_reranker_strategy"] == "deterministic"
        await session._handle_client_data_event(
            json.dumps(
                {
                    "type": "memory_lookup_response",
                    "turn_id": request["turn_id"],
                    "request_sequence": request["sequence"],
                    "elapsed_ms": 12,
                    "memory_packets": [_memory_packet()],
                }
            )
        )
        await task

    asyncio.run(scenario())

    assert len(llm.calls) == 1
    context_text = "\n".join(message.content for message in llm.calls[0])
    assert "[semantic_memory]" in context_text
    assert "manager pressure" in context_text
    logs = capsys.readouterr().out
    assert "memory_lookup_metrics" in logs
    assert "candidates_returned" in logs
    assert "candidates_injected" in logs
    assert "context_char_budget" in logs
    assert "retrieval_strategy" in logs


def test_query_time_memory_lookup_can_carry_pending_receipt_prompt() -> None:
    transport = MemoryAgentTransport()
    llm = RecordingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
        llm_provider=llm,
    )

    async def scenario() -> None:
        task = asyncio.create_task(
            session._respond_to_final_transcript("session_test:turn:0010", "office bad day tha")
        )
        request = await _wait_for_decoded_event_type(transport, "memory_lookup_request")
        await session._handle_client_data_event(
            json.dumps(
                {
                    "type": "memory_lookup_response",
                    "turn_id": request["turn_id"],
                    "request_sequence": request["sequence"],
                    "elapsed_ms": 12,
                    "memory_packets": [_memory_packet()],
                    "pending_receipts": [
                        {
                            "memory_id": "memory_semantic_work_stress_manager",
                            "kind": "semantic",
                            "label": "recurring_work_stressor",
                            "content": "User has previously mentioned work stress related to manager pressure.",
                            "confidence_score": 0.68,
                            "importance_score": 0.72,
                            "evidence_summary": "Recurring work/office stress signal from local turns.",
                        }
                    ],
                }
            )
        )
        await task

    asyncio.run(scenario())

    context_text = "\n".join(message.content for message in llm.calls[0])
    assert "[memory_receipt]" in context_text
    assert "Potential memory" in context_text
    assert "voice-only confirmation question" in context_text


def test_query_time_memory_lookup_timeout_falls_back_without_memory() -> None:
    transport = MemoryAgentTransport()
    llm = RecordingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
        llm_provider=llm,
    )

    async def scenario() -> None:
        await session._respond_to_final_transcript("session_test:turn:0006", "office bad day tha")

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assert any(event["type"] == "memory_lookup_request" for event in events)
    assert len(llm.calls) == 1
    context_text = "\n".join(message.content for message in llm.calls[0])
    assert "manager pressure" not in context_text
    assert context_text.endswith("office bad day tha")


def test_v2_exact_state_reply_bypasses_llm_and_uses_matching_turn() -> None:
    transport = MemoryAgentTransport()
    llm = RecordingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
        llm_provider=llm,
    )

    async def scenario() -> None:
        await session._handle_client_data_event(
            json.dumps(
                {
                    "type": "client_session_started",
                    "schema_version": 2,
                    "memory_protocol_versions": [1, 2],
                }
            )
        )
        task = asyncio.create_task(
            session._respond_to_final_transcript("session_test:turn:0042", "मेरा नाम क्या है?")
        )
        request = await _wait_for_decoded_event_type(transport, "memory_context_request_v2")
        assert request["language"] == "hi-IN"
        await session._handle_client_data_event(
            json.dumps(
                {
                    "type": "memory_context_response_v2",
                    "turn_id": request["turn_id"],
                    "request_sequence": request["sequence"],
                    "response_directive": "fact_answer",
                    "state_facts": [
                        {
                            "claim_id": "claim_amit",
                            "state_key": "user.profile.preferred_name",
                            "value": {"text": "अमित"},
                            "value_type": "profile",
                        }
                    ],
                }
            )
        )
        await task

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    final = next(event for event in events if event["type"] == "assistant_transcript_final")
    assert final["turn_id"] == "session_test:turn:0042"
    assert final["text"] == "आपका नाम अमित है।"
    assert llm.calls == []


def test_v2_low_risk_admission_uses_llm_with_relationship_role_guard() -> None:
    transport = MemoryAgentTransport()
    llm = RecordingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
        llm_provider=llm,
    )

    async def scenario() -> None:
        await session._handle_client_data_event(
            json.dumps(
                {
                    "type": "client_session_started",
                    "schema_version": 2,
                    "memory_protocol_versions": [1, 2],
                }
            )
        )
        task = asyncio.create_task(
            session._respond_to_final_transcript(
                "session_test:turn:0043",
                "मेरे भाई का नाम रोहन है",
            )
        )
        request = await _wait_for_decoded_event_type(transport, "memory_context_request_v2")
        await session._handle_client_data_event(
            json.dumps(
                {
                    "type": "memory_context_response_v2",
                    "turn_id": request["turn_id"],
                    "request_sequence": request["sequence"],
                    "response_directive": "setting_ack",
                    "state_facts": [
                        {
                            "claim_id": "claim_rohan",
                            "state_key": "user.relationship.brother.रोहन",
                            "value": {"text": "रोहन"},
                            "value_type": "relationship",
                        }
                    ],
                }
            )
        )
        await task

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    final = next(event for event in events if event["type"] == "assistant_transcript_final")
    prompt = "\n".join(message.content for message in llm.calls[0])
    assert final["text"] == "recorded reply"
    assert len(llm.calls) == 1
    assert "[turn_admission]" in prompt
    assert "brother is named रोहन" in prompt
    assert "never address the user as रोहन" in prompt


def test_llm_output_sanitizes_internal_context_markers() -> None:
    assert (
        _sanitize_llm_output("[recent_turns] Haan, main sun raha hoon. [latest_user]")
        == "Haan, main sun raha hoon."
    )


def test_stale_memory_lookup_response_is_ignored_until_matching_response_arrives() -> None:
    transport = MemoryAgentTransport()
    llm = RecordingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
        llm_provider=llm,
    )

    async def scenario() -> None:
        task = asyncio.create_task(
            session._respond_to_final_transcript("session_test:turn:0007", "office bad day tha")
        )
        request = await _wait_for_decoded_event_type(transport, "memory_lookup_request")
        await session._handle_client_data_event(
            json.dumps(
                {
                    "type": "memory_lookup_response",
                    "turn_id": request["turn_id"],
                    "request_sequence": int(request["sequence"]) + 100,
                    "memory_packets": [
                        _memory_packet(
                            memory_id="stale_memory",
                            content="Stale memory should not reach the prompt.",
                        )
                    ],
                }
            )
        )
        assert llm.calls == []
        await session._handle_client_data_event(
            json.dumps(
                {
                    "type": "memory_lookup_response",
                    "turn_id": request["turn_id"],
                    "request_sequence": request["sequence"],
                    "memory_packets": [_memory_packet()],
                }
            )
        )
        await task

    asyncio.run(scenario())

    context_text = "\n".join(message.content for message in llm.calls[0])
    assert "manager pressure" in context_text
    assert "Stale memory" not in context_text


def test_safety_and_greeting_routes_do_not_send_memory_lookup() -> None:
    transport = MemoryAgentTransport()
    llm = CountingLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
        llm_provider=llm,
    )

    async def scenario() -> None:
        await session._respond_to_final_transcript("session_test:turn:0008", "hi")
        await session._respond_to_final_transcript(
            "session_test:turn:0009",
            "main mar jaana chahta hoon",
        )

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assert not any(event["type"] == "memory_lookup_request" for event in events)
    assert llm.calls == 1
    assistant = [event for event in events if event["type"] == "assistant_transcript_final"][-1]
    assert assistant["status"] == "safety_override"


def test_empty_stt_result_requests_repeat_without_thinking_state() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        stt_provider=EmptySTTProvider(),
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        for _ in range(8):
            await transport.activity.put(pcm_sine_frame(duration_ms=30, amplitude=5000))
        for _ in range(24):
            await transport.activity.put(pcm_silence_frame(duration_ms=30))
        await _wait_for_event_type(transport, "transcript_repeat_requested")
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assert any(
        event["type"] == "transcript_repeat_requested" and event.get("reason") == "empty_transcript"
        for event in events
    )
    assert not any(
        event["type"] == "session_state" and event.get("state") == "thinking" for event in events
    )


def test_new_final_transcript_cancels_overlapping_response_task() -> None:
    transport = MemoryAgentTransport(audio_publish_delay_seconds=1)
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        tts_provider=SlowTTSProvider(),
    )

    async def scenario() -> bool:
        await session._handle_final_transcript(
            "session_test:turn:0001",
            TranscriptEvent(
                text="pehla turn",
                is_final=True,
                confidence=0.99,
                provider="test-static",
                model="test",
            ),
        )
        await _wait_for_state(transport, "speaking")
        first_task = session._current_turn
        assert first_task is not None

        await session._handle_final_transcript(
            "session_test:turn:0002",
            TranscriptEvent(
                text="dusra turn",
                is_final=True,
                confidence=0.99,
                provider="test-static",
                model="test",
            ),
        )
        await asyncio.sleep(0)
        second_task = session._current_turn
        assert second_task is not None
        second_task.cancel()
        await asyncio.gather(first_task, second_task, return_exceptions=True)
        return first_task.cancelled() and second_task is not first_task

    assert asyncio.run(scenario()) is True


def test_continuation_before_response_is_coalesced_into_original_turn() -> None:
    transport = MemoryAgentTransport()
    llm = CancelThenReplyLLMProvider()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(vad_provider="energy"),
        transport=transport,
        llm_provider=llm,
    )

    async def scenario() -> None:
        await session._handle_final_transcript(
            "session_test:turn:0001",
            TranscriptEvent(
                text="पहला वाक्य",
                is_final=True,
                confidence=0.99,
                provider="test-static",
                model="test",
            ),
        )
        await llm.first_call_started.wait()

        await session._handle_endpoint_event(
            EndpointEvent(
                type="speech_start",
                turn_id="session_test:turn:0002",
                elapsed_ms=100,
            )
        )
        await session._handle_final_transcript(
            "session_test:turn:0002",
            TranscriptEvent(
                text="दूसरा वाक्य",
                is_final=True,
                confidence=0.99,
                provider="test-static",
                model="test",
            ),
        )
        await _wait_for_event_type(transport, "assistant_transcript_final")
        if session._current_turn is not None:
            await session._current_turn

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    finals = [event for event in events if event["type"] == "transcript_final"]
    assert finals[-1]["turn_id"] == "session_test:turn:0001"
    assert finals[-1]["text"] == "पहला वाक्य दूसरा वाक्य"
    assert finals[-1]["coalesced"] is True
    assert finals[-1]["coalesced_segments"] == 2
    assert llm.cancelled_first_call is True
    assert len(llm.calls) == 2


def test_wait_until_started_does_not_cancel_agent_task() -> None:
    async def scenario() -> bool:
        started = asyncio.Event()

        async def long_running_agent() -> None:
            started.set()
            await asyncio.Event().wait()

        task = asyncio.create_task(long_running_agent())
        await _wait_until_started(task, started)
        still_running = not task.done()
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        return still_running

    assert asyncio.run(scenario()) is True


def _assignment(
    *,
    recent_context: dict[str, object] | list[dict[str, object]],
) -> AgentAssignment:
    return AgentAssignment(
        session_id="session_test",
        room_name="companion_session_test",
        expires_at_ms=int(time.time() * 1000) + 60_000,
        recent_context=recent_context,
    )


def _settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "livekit_api_key": "devkey",
        "livekit_api_secret": "secret",
        "enable_livekit_rtc": False,
        "max_idle_seconds": 1,
        "fake_audio_ms": 20,
        "tts_provider": "mock",
        # Keep lifecycle tests fast; endpointing-specific tests cover the
        # production coalescing window explicitly.
        "vad_coalescing_silence_ms": 600,
    }
    values.update(overrides)
    return Settings(
        **values,
    )


async def _wait_for_events(transport: MemoryAgentTransport, *, minimum: int) -> None:
    for _ in range(50):
        if len(transport.events) >= minimum:
            return
        await asyncio.sleep(0.01)
    raise AssertionError(f"expected at least {minimum} events, saw {len(transport.events)}")


async def _wait_for_state(transport: MemoryAgentTransport, state: str) -> None:
    for _ in range(50):
        if any(_decode(event).get("state") == state for event in transport.events):
            return
        await asyncio.sleep(0.01)
    raise AssertionError(f"expected state {state}")


async def _wait_for_event_type(transport: MemoryAgentTransport, event_type: str) -> None:
    for _ in range(50):
        if any(_decode(event).get("type") == event_type for event in transport.events):
            return
        await asyncio.sleep(0.01)
    raise AssertionError(f"expected event type {event_type}")


async def _wait_for_decoded_event_type(
    transport: MemoryAgentTransport,
    event_type: str,
) -> dict[str, object]:
    for _ in range(50):
        for event in transport.events:
            decoded = _decode(event)
            if decoded.get("type") == event_type:
                return decoded
        await asyncio.sleep(0.01)
    raise AssertionError(f"expected event type {event_type}")


def _decode(data: bytes) -> dict[str, object]:
    decoded = json.loads(data.decode("utf-8"))
    assert isinstance(decoded, dict)
    return decoded


def _memory_packet(
    *,
    memory_id: str = "memory_work_stress",
    content: str = "User has previously mentioned office stress from manager pressure.",
) -> dict[str, object]:
    return {
        "memory_id": memory_id,
        "kind": "semantic",
        "label": "recurring_work_stressor",
        "content": content,
        "canonical_text": "work stress office manager pressure",
        "source_turn_ids": ["turn_old"],
        "source_role": "user",
        "transcript_status": "final",
        "stt_confidence": 0.99,
        "created_at_ms": 1,
        "updated_at_ms": 2,
        "last_used_at_ms": None,
        "confidence_score": 0.82,
        "importance_score": 0.76,
        "recurrence_count": 1,
        "sensitivity": "normal",
        "temporal_status": "current",
        "receipt_state": "implicit",
        "evidence_summary": "Local prior complete turn.",
    }


class EmptySTTProvider(STTProvider):
    async def stream(self, audio_frames, language: str):  # noqa: ANN001
        audio_seconds = 0.0
        async for frame in audio_frames:
            assert isinstance(frame, CanonicalAudioFrame)
            audio_seconds += frame.duration_ms / 1000
        yield TranscriptEvent(
            text="",
            is_final=True,
            confidence=None,
            provider="test-empty",
            model="test",
            latency_ms=3,
            audio_seconds=audio_seconds,
        )


class StaticSTTProvider(STTProvider):
    def __init__(self, text: str) -> None:
        self.text = text

    async def stream(self, audio_frames, language: str):  # noqa: ANN001
        audio_seconds = 0.0
        async for frame in audio_frames:
            assert isinstance(frame, CanonicalAudioFrame)
            audio_seconds += frame.duration_ms / 1000
        yield TranscriptEvent(
            text=self.text,
            is_final=True,
            confidence=0.99,
            provider="test-static",
            model="test",
            latency_ms=3,
            audio_seconds=audio_seconds,
        )


class FailingLLMProvider(LLMProvider):
    async def stream(
        self,
        messages: list[LLMMessage],
        language: str,
        *,
        max_output_chars: int,
    ):
        raise RuntimeError("simulated LLM failure")
        yield  # pragma: no cover


class LongLLMProvider(LLMProvider):
    async def stream(
        self,
        messages: list[LLMMessage],
        language: str,
        *,
        max_output_chars: int,
    ):
        yield LLMToken(
            text=" ".join(["bahut lamba jawab"] * 40),
            provider="test-long",
            model="test",
        )


class CountingLLMProvider(LLMProvider):
    def __init__(self) -> None:
        self.calls = 0

    async def stream(
        self,
        messages: list[LLMMessage],
        language: str,
        *,
        max_output_chars: int,
    ):
        self.calls += 1
        yield LLMToken(text="normal reply", provider="test-counting", model="test")


class CancelThenReplyLLMProvider(LLMProvider):
    def __init__(self) -> None:
        self.calls: list[list[LLMMessage]] = []
        self.first_call_started = asyncio.Event()
        self.cancelled_first_call = False

    async def stream(
        self,
        messages: list[LLMMessage],
        language: str,
        *,
        max_output_chars: int,
    ):
        self.calls.append(messages)
        if len(self.calls) == 1:
            self.first_call_started.set()
            try:
                await asyncio.Event().wait()
            except asyncio.CancelledError:
                self.cancelled_first_call = True
                raise
        yield LLMToken(text="combined reply", provider="test-coalesced", model="test")


class RecordingLLMProvider(LLMProvider):
    def __init__(self) -> None:
        self.calls: list[list[LLMMessage]] = []

    async def stream(
        self,
        messages: list[LLMMessage],
        language: str,
        *,
        max_output_chars: int,
    ):
        self.calls.append(messages)
        yield LLMToken(text="recorded reply", provider="test-recording", model="test")


class StaticTTSProvider(TTSProvider):
    async def synthesize(self, text: str, language: str):  # noqa: ANN001
        for _ in range(2):
            yield TTSAudioFrame(
                frame=pcm_sine_frame(duration_ms=20, sample_rate=16000),
                provider="test-tts",
                model="test",
                text=text,
                latency_ms=5,
                audio_ms=20,
                chars=len(text),
                billed_units=float(len(text)),
                cost_units=len(text) * 0.003,
            )


class SlowTTSProvider(TTSProvider):
    async def synthesize(self, text: str, language: str):  # noqa: ANN001
        yield TTSAudioFrame(
            frame=pcm_sine_frame(duration_ms=20, sample_rate=16000),
            provider="test-tts",
            model="test",
            text=text,
            latency_ms=5,
            audio_ms=20,
            chars=len(text),
            billed_units=float(len(text)),
            cost_units=len(text) * 0.003,
        )
        await asyncio.sleep(5)
