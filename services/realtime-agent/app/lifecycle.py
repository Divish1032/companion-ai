from __future__ import annotations

import asyncio
import json
import math
import struct
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Protocol

import httpx

from livekit import api, rtc

from app.audio_pipeline import (
    CanonicalAudioFrame,
    EndpointEvent,
    EndpointingStateMachine,
    create_vad_provider,
)
from app.config import Settings, load_persona_settings
from app.context import PromptContextBuilder
from app.events import EventSequencer, TurnIdFactory
from app.memory_router import route_memory_query
from app.memory_router import MemoryRoutingDecision
from app.memory_planner import HttpMemoryPlanner, MemoryPlanner
from app.providers import (
    LLMProvider,
    LLMProviderUnavailable,
    MemoryStrategyRoute,
    FailoverTTSProvider,
    KokoroTTSProvider,
    ProviderRouting,
    SarvamBulbulTTSProvider,
    SarvamChatLLMProvider,
    SarvamSTTProvider,
    STTProvider,
    TTSProvider,
    VoskSTTProvider,
)
from app.providers.interfaces import LLMMessage, LLMToken, TTSAudioFrame, TranscriptEvent
from app.providers.mock import MockLLMProvider, MockSTTProvider, MockTTSProvider
from app.safety import SafetyClassifier
from app.telemetry import (
    TurnMetricsCollector,
    llm_cost_micro_inr,
    stt_cost_micro_inr,
    tts_cost_micro_inr,
)
from app.voice_catalog import load_voice_catalog


class AgentAssignmentError(Exception):
    pass


@dataclass(frozen=True)
class AgentAssignment:
    session_id: str
    room_name: str
    expires_at_ms: int
    recent_context: dict[str, object] | list[dict[str, object]]
    language: str = "hi-IN"
    voice_id: str | None = None


class AgentTransport(Protocol):
    async def connect(self) -> None: ...
    async def publish_reliable(self, payload: bytes, topic: str = "critical") -> None: ...
    async def publish_lossy(self, payload: bytes, topic: str = "diagnostic") -> None: ...
    async def publish_placeholder_audio(self, duration_ms: int) -> None: ...
    async def publish_audio_frame(self, frame: CanonicalAudioFrame) -> None: ...
    async def stop_audio(self, *, fade_out_ms: int) -> None: ...
    async def wait_for_client_activity(
        self, timeout_seconds: float
    ) -> str | CanonicalAudioFrame | None: ...
    async def disconnect(self) -> None: ...


class LiveKitAgentTransport:
    def __init__(self, *, assignment: AgentAssignment, settings: Settings) -> None:
        self.assignment = assignment
        self.settings = settings
        self.room: rtc.Room | None = None
        self._activity_queue: asyncio.Queue[str | CanonicalAudioFrame] = asyncio.Queue()
        self._audio_source: rtc.AudioSource | None = None
        self._audio_source_sample_rate = 16000
        self._audio_source_num_channels = 1
        self._audio_track_published = False
        self._seen_user_audio = False
        self._audio_tasks: set[asyncio.Task[None]] = set()
        self._audio_publish_lock = asyncio.Lock()

    def _bind_room_handlers(self, room: rtc.Room) -> None:

        @room.on("track_subscribed")
        def on_track_subscribed(track, publication, participant) -> None:  # noqa: ANN001
            if getattr(track, "kind", None) == rtc.TrackKind.KIND_AUDIO:
                self._seen_user_audio = True
                task = asyncio.create_task(self._consume_audio_track(track))
                self._audio_tasks.add(task)
                task.add_done_callback(self._audio_tasks.discard)

        @room.on("data_received")
        def on_data_received(data_packet) -> None:  # noqa: ANN001
            payload = getattr(data_packet, "data", b"")
            if isinstance(payload, str):
                payload = payload.encode("utf-8")
            self._activity_queue.put_nowait(payload.decode("utf-8", errors="ignore"))

        @room.on("participant_disconnected")
        def on_participant_disconnected(participant) -> None:  # noqa: ANN001
            identity = getattr(participant, "identity", "")
            if identity.startswith("device_"):
                self._activity_queue.put_nowait("client_left")

    async def connect(self) -> None:
        if not self.settings.livekit_api_key or not self.settings.livekit_api_secret:
            raise AgentAssignmentError("LiveKit credentials are not configured for agent.")

        self.room = rtc.Room()
        self._bind_room_handlers(self.room)
        token = (
            api.AccessToken(self.settings.livekit_api_key, self.settings.livekit_api_secret)
            .with_identity(f"agent_{self.assignment.session_id[:48]}")
            .with_name("Companion AI agent")
            .with_grants(
                api.VideoGrants(
                    room_join=True,
                    room=self.assignment.room_name,
                    can_publish=True,
                    can_publish_data=True,
                    can_subscribe=True,
                )
            )
            .to_jwt()
        )
        await self.room.connect(
            self.settings.livekit_url,
            token,
            rtc.RoomOptions(auto_subscribe=True),
        )

    async def publish_reliable(self, payload: bytes, topic: str = "critical") -> None:
        if self.room is None:
            raise AgentAssignmentError("LiveKit room is not connected.")
        await self.room.local_participant.publish_data(payload, reliable=True, topic=topic)

    async def publish_lossy(self, payload: bytes, topic: str = "diagnostic") -> None:
        if self.room is None:
            raise AgentAssignmentError("LiveKit room is not connected.")
        await self.room.local_participant.publish_data(payload, reliable=False, topic=topic)

    async def publish_placeholder_audio(self, duration_ms: int) -> None:
        if not self.settings.enable_fake_audio:
            return
        if self.room is None:
            raise AgentAssignmentError("LiveKit room is not connected.")

        if self._audio_source is None:
            self._audio_source = rtc.AudioSource(sample_rate=16000, num_channels=1)
            self._audio_source_sample_rate = 16000
            self._audio_source_num_channels = 1
        if not self._audio_track_published:
            track = rtc.LocalAudioTrack.create_audio_track("fake-ai-audio", self._audio_source)
            await self.room.local_participant.publish_track(track)
            self._audio_track_published = True

        for frame in _placeholder_pcm_frames(duration_ms=duration_ms):
            await self._audio_source.capture_frame(frame)

    async def publish_audio_frame(self, frame: CanonicalAudioFrame) -> None:
        async with self._audio_publish_lock:
            if self.room is None:
                raise AgentAssignmentError("LiveKit room is not connected.")
            if self._audio_source is None:
                self._audio_source = rtc.AudioSource(
                    sample_rate=frame.sample_rate,
                    num_channels=frame.num_channels,
                )
                self._audio_source_sample_rate = frame.sample_rate
                self._audio_source_num_channels = frame.num_channels
            if not self._audio_track_published:
                track = rtc.LocalAudioTrack.create_audio_track("ai-audio", self._audio_source)
                await self.room.local_participant.publish_track(track)
                self._audio_track_published = True
            await self._audio_source.capture_frame(
                rtc.AudioFrame(
                    data=frame.pcm16,
                    sample_rate=frame.sample_rate,
                    num_channels=frame.num_channels,
                    samples_per_channel=max(len(frame.pcm16) // (2 * frame.num_channels), 1),
                )
            )

    async def stop_audio(self, *, fade_out_ms: int) -> None:
        async with self._audio_publish_lock:
            if self._audio_source is None:
                return
            sample_rate = self._audio_source_sample_rate
            num_channels = self._audio_source_num_channels
            samples = max(round(sample_rate * fade_out_ms / 1000), 1)
            try:
                await self._audio_source.capture_frame(
                    rtc.AudioFrame(
                        data=b"\x00\x00" * samples * num_channels,
                        sample_rate=sample_rate,
                        num_channels=num_channels,
                        samples_per_channel=samples,
                    )
                )
            except Exception:
                self._audio_source = None
                self._audio_track_published = False
                return

    async def wait_for_client_activity(
        self, timeout_seconds: float
    ) -> str | CanonicalAudioFrame | None:
        try:
            return await asyncio.wait_for(self._activity_queue.get(), timeout_seconds)
        except TimeoutError:
            return None

    async def disconnect(self) -> None:
        for task in self._audio_tasks:
            task.cancel()
        if self._audio_tasks:
            await asyncio.gather(*self._audio_tasks, return_exceptions=True)
            self._audio_tasks.clear()
        if self.room is not None:
            await self.room.disconnect()
            self.room = None

    async def _consume_audio_track(self, track) -> None:  # noqa: ANN001
        stream = rtc.AudioStream.from_track(
            track=track,
            sample_rate=16000,
            num_channels=1,
            frame_size_ms=30,
        )
        try:
            async for event in stream:
                frame = getattr(event, "frame", event)
                canonical = _canonical_frame_from_livekit(frame)
                if canonical is not None:
                    self._activity_queue.put_nowait(canonical)
        finally:
            await stream.aclose()


class MemoryAgentTransport:
    def __init__(self, *, audio_publish_delay_seconds: float = 0) -> None:
        self.events: list[bytes] = []
        self.lossy_events: list[bytes] = []
        self.audio_publications = 0
        self.connected = False
        self.disconnected = False
        self.activity: asyncio.Queue[str | CanonicalAudioFrame] = asyncio.Queue()
        self.audio_publish_delay_seconds = audio_publish_delay_seconds

    async def connect(self) -> None:
        self.connected = True

    async def publish_reliable(self, payload: bytes, topic: str = "critical") -> None:
        self.events.append(payload)

    async def publish_lossy(self, payload: bytes, topic: str = "diagnostic") -> None:
        self.lossy_events.append(payload)

    async def publish_placeholder_audio(self, duration_ms: int) -> None:
        self.audio_publications += 1
        if self.audio_publish_delay_seconds > 0:
            await asyncio.sleep(self.audio_publish_delay_seconds)

    async def publish_audio_frame(self, frame: CanonicalAudioFrame) -> None:
        self.audio_publications += 1
        if self.audio_publish_delay_seconds > 0:
            await asyncio.sleep(self.audio_publish_delay_seconds)

    async def stop_audio(self, *, fade_out_ms: int) -> None:
        self.audio_publications += 1

    async def wait_for_client_activity(
        self, timeout_seconds: float
    ) -> str | CanonicalAudioFrame | None:
        try:
            return await asyncio.wait_for(self.activity.get(), timeout_seconds)
        except TimeoutError:
            return None

    async def disconnect(self) -> None:
        self.disconnected = True


class RealtimeAgentSession:
    def __init__(
        self,
        *,
        assignment: AgentAssignment,
        settings: Settings,
        transport: AgentTransport,
        stt_provider: STTProvider | None = None,
        llm_provider: LLMProvider | None = None,
        tts_provider: TTSProvider | None = None,
        safety_classifier: SafetyClassifier | None = None,
        memory_planner: MemoryPlanner | None = None,
    ) -> None:
        self.assignment = assignment
        self.settings = settings
        self.transport = transport
        self.stt_provider = stt_provider or create_stt_provider(settings)
        self.llm_provider = llm_provider or create_llm_provider(settings)
        self.tts_provider = tts_provider or create_tts_provider(
            settings,
            language=assignment.language,
            voice_id=assignment.voice_id,
        )
        self.safety_classifier = safety_classifier or SafetyClassifier()
        self.memory_strategy = selected_memory_strategy(settings)
        self.memory_planner = memory_planner or HttpMemoryPlanner(
            base_url=settings.memory_api_base_url,
            model=settings.memory_planner_model,
            timeout_seconds=settings.memory_planner_timeout_seconds,
        )
        self.persona = load_persona_settings(settings)
        self.context_builder = PromptContextBuilder(
            system_prompt=self.persona.system_prompt,
            initial_context=assignment.recent_context,
            max_recent_messages=self.persona.history_messages,
        )
        self.sequencer = EventSequencer(assignment.session_id)
        self.telemetry = TurnMetricsCollector(assignment.session_id)
        self.turn_ids = TurnIdFactory(assignment.session_id)
        self._stt_streams: dict[str, _STTTurnStream] = {}
        self._latest_partial_transcript: dict[str, str] = {}
        self.endpointing = EndpointingStateMachine(
            config=settings.vad_config(),
            vad_provider=create_vad_provider(settings.vad_config()),
            turn_id_factory=self.turn_ids.next,
            stt_audio_sink=self._record_stt_audio,
        )
        self._current_turn: asyncio.Task[None] | None = None
        self._pending_memory_requests: dict[
            tuple[str, int], asyncio.Future[tuple[list[dict[str, object]], list[dict[str, object]]]]
        ] = {}
        self._pending_memory_context_requests: dict[
            tuple[str, int], asyncio.Future[dict[str, object]]
        ] = {}
        self._memory_lookup_latency_ms: dict[str, int] = {}
        self._stopped = asyncio.Event()
        self.started = asyncio.Event()
        self._assistant_speaking = False
        self._active_response_turn_id: str | None = None
        self._response_user_text: dict[str, str] = {}
        self._turn_stt_confidence: dict[str, float | None] = {}
        self._turn_stt_metadata: dict[str, tuple[str, str]] = {}
        self._client_supports_memory_v2 = False
        self._response_committed_turns: set[str] = set()
        self._pending_coalesced_turn: tuple[str, str] | None = None
        self._relayed_memory_notice_ids: set[str] = set()

    async def run(self) -> None:
        try:
            await self.transport.connect()
            self.started.set()
            await self._emit_state("listening", turn_id=None)
            await self._loop_until_shutdown()
        except asyncio.CancelledError:
            self.cancel_current_turn()
            raise
        except Exception as error:
            await self._emit_error(str(error))
            raise
        finally:
            self.cancel_current_turn()
            await self.close_stt_streams()
            await self.tts_provider.close()
            await self.transport.disconnect()

    def cancel_current_turn(self) -> bool:
        if self._current_turn is None or self._current_turn.done():
            return False
        self._current_turn.cancel()
        self._assistant_speaking = False
        if self._active_response_turn_id is not None:
            self.telemetry.turn(self._active_response_turn_id).mark("cancel_requested")
        return True

    async def close_stt_streams(self) -> None:
        tasks = []
        for stream in self._stt_streams.values():
            stream.close()
            if stream.task is not None and not stream.task.done():
                stream.task.cancel()
                tasks.append(stream.task)
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        self._stt_streams.clear()
        self._latest_partial_transcript.clear()

    async def _loop_until_shutdown(self) -> None:
        while not self._stopped.is_set():
            now_ms = int(asyncio.get_running_loop().time() * 1000)
            expires_in_seconds = max((self.assignment.expires_at_ms - _wall_clock_ms()) / 1000, 0)
            timeout = min(float(self.settings.max_idle_seconds), expires_in_seconds)
            if timeout <= 0:
                return

            activity = await self.transport.wait_for_client_activity(timeout)
            if activity is None:
                return
            if isinstance(activity, CanonicalAudioFrame):
                await self._handle_audio_frame(activity)
                continue
            if activity == "client_left":
                return
            if await self._handle_client_data_event(activity):
                continue
            if "client_cancel_turn" in activity:
                self.cancel_current_turn()
                await self._emit_state("listening", turn_id=None)
                continue
            if "client_session_started" in activity:
                continue
            if "client_fake_turn" in activity and (
                self._current_turn is None or self._current_turn.done()
            ):
                self._current_turn = asyncio.create_task(self._run_fake_turn())
            _ = now_ms

    async def _run_fake_turn(self) -> None:
        turn_id = self.turn_ids.next()
        await self._emit_state("thinking", turn_id=turn_id)

        prompt = self.context_builder.latest_recent_user_text()
        if not prompt:
            prompt = "mock pipeline turn"

        decision = self.safety_classifier.classify_input(prompt)
        if decision.response_override is not None:
            response_text = decision.response_override
            await self._emit_state("speaking", turn_id=turn_id, safety_reason=decision.reason)
        else:
            await self._emit_filler("started", turn_id)
            await asyncio.sleep(0.05)
            await self._emit_filler("stopped", turn_id)
            response_text = await self.llm_provider.respond(prompt, "hi-IN")
            await self._emit_state("speaking", turn_id=turn_id)

        async for _chunk in self.tts_provider.synthesize(response_text, "hi-IN"):
            await self.transport.publish_placeholder_audio(self.settings.fake_audio_ms)
            break
        await self._emit_state("listening", turn_id=turn_id)

    async def _emit_state(
        self,
        state: str,
        *,
        turn_id: str | None,
        safety_reason: str | None = None,
    ) -> None:
        payload: dict[str, object] = {
            "state": state,
            "source": "realtime_agent",
            "latency_ms": 0,
            "cost_units": 0,
        }
        if safety_reason is not None:
            payload["safety_reason"] = safety_reason
        self._assistant_speaking = state == "speaking"
        await self.transport.publish_reliable(
            self.sequencer.encode(event_type="session_state", turn_id=turn_id, payload=payload)
        )

    async def _emit_filler(self, state: str, turn_id: str) -> None:
        await self.transport.publish_reliable(
            self.sequencer.encode(
                event_type="filler_audio",
                turn_id=turn_id,
                payload={"state": state, "clip_id": "deferred_static_hinglish_ack"},
            )
        )

    async def _emit_error(self, message: str) -> None:
        await self.transport.publish_reliable(
            self.sequencer.encode(
                event_type="error",
                payload={"error_code": _error_code(message), "source": "realtime_agent"},
            )
        )

    async def _handle_audio_frame(self, frame: CanonicalAudioFrame) -> None:
        partial = (
            self._latest_partial_transcript.get(self.endpointing.current_turn_id)
            if self.endpointing.current_turn_id is not None
            else None
        )
        for event in self.endpointing.process_frame(frame, partial_transcript=partial):
            await self._handle_endpoint_event(event)

    async def _handle_endpoint_event(self, event: EndpointEvent) -> None:
        metric = self.telemetry.turn(event.turn_id)
        metric.statuses["vad_provider"] = self.settings.vad_provider
        if event.type == "speech_start":
            metric.mark("server_vad_speech_start")
        elif event.type == "speech_end":
            metric.mark("server_vad_speech_end")
        elif event.type == "endpoint_commit":
            metric.mark("server_endpoint_commit")
        metric.counts["forwarded_audio_ms"] = event.forwarded_audio_ms
        if event.type == "speech_start":
            if (
                self._current_turn is not None
                and not self._current_turn.done()
                and self._active_response_turn_id is not None
                and self._active_response_turn_id not in self._response_committed_turns
            ):
                previous_text = self._response_user_text.get(self._active_response_turn_id)
                if previous_text:
                    self._pending_coalesced_turn = (
                        self._active_response_turn_id,
                        previous_text,
                    )
                    print(
                        "turn_coalescing_started",
                        {
                            "session_id": self.assignment.session_id,
                            "turn_id": self._active_response_turn_id,
                            "continuation_turn_id": event.turn_id,
                        },
                        flush=True,
                    )
            if self._assistant_speaking or (
                self._current_turn is not None and not self._current_turn.done()
            ):
                stage = "during_speaking" if self._assistant_speaking else "before_tts"
                cancelled = self.cancel_current_turn()
                await self.transport.stop_audio(fade_out_ms=60)
                await self._emit_barge_in(event, cancelled=cancelled, stage=stage)
            await self._emit_endpoint_event(event)
            await self._emit_state("user_speaking", turn_id=event.turn_id)
            return

        await self._emit_endpoint_event(event)
        if event.type == "speech_end":
            await self._emit_state("listening", turn_id=event.turn_id)
        if event.type == "endpoint_commit":
            await self._finish_stt_turn(event.turn_id)

    async def _emit_endpoint_event(self, event: EndpointEvent) -> None:
        payload = {
            "elapsed_ms": event.elapsed_ms,
            "reason": event.reason,
            "pre_speech_ms": event.pre_speech_ms,
            "forwarded_audio_ms": event.forwarded_audio_ms,
            "vad_provider": self.settings.vad_config().provider,
        }
        await self.transport.publish_reliable(
            self.sequencer.encode(event_type=event.type, turn_id=event.turn_id, payload=payload)
        )

    async def _emit_barge_in(
        self,
        event: EndpointEvent,
        *,
        cancelled: bool,
        stage: str,
    ) -> None:
        payload = {
            "stage": stage,
            "cancelled": cancelled,
            "elapsed_ms": event.elapsed_ms,
        }
        await self.transport.publish_reliable(
            self.sequencer.encode(event_type="barge_in", turn_id=event.turn_id, payload=payload)
        )
        print(
            "barge_in",
            {
                "session_id": self.assignment.session_id,
                "turn_id": event.turn_id,
                "stage": stage,
                "cancelled": cancelled,
                "elapsed_ms": event.elapsed_ms,
            },
            flush=True,
        )

    def _record_stt_audio(self, frame: CanonicalAudioFrame) -> None:
        turn_id = self.endpointing.current_turn_id
        if turn_id is None:
            return
        stream = self._stt_streams.get(turn_id)
        if stream is None:
            stream = _STTTurnStream(turn_id=turn_id)
            self._stt_streams[turn_id] = stream
            stream.task = asyncio.create_task(self._run_stt_stream(stream))
        stream.push(frame)

    async def _run_stt_stream(self, stream: "_STTTurnStream") -> None:
        try:
            async for event in self.stt_provider.stream(stream.frames(), self.settings.language):
                if event.is_final:
                    await self._handle_final_transcript(stream.turn_id, event)
                else:
                    self._latest_partial_transcript[stream.turn_id] = event.text
                    await self._emit_transcript_partial(stream.turn_id, event)
        except asyncio.CancelledError:
            raise
        except Exception as error:
            await self._emit_stt_error(stream.turn_id, str(error))

    async def _finish_stt_turn(self, turn_id: str) -> None:
        stream = self._stt_streams.pop(turn_id, None)
        if stream is None:
            await self._emit_transcript_repeat(
                turn_id,
                reason="empty_transcript",
                metrics={"audio_seconds": 0, "billed_units": 0, "cost_units": 0},
            )
            return
        stream.close()
        if stream.task is not None:
            await stream.task
        self._latest_partial_transcript.pop(turn_id, None)

    async def _emit_transcript_partial(self, turn_id: str, event: TranscriptEvent) -> None:
        await self.transport.publish_lossy(
            self.sequencer.encode(
                event_type="transcript_partial",
                turn_id=turn_id,
                payload={
                    "text": event.text,
                    "language": self.settings.language,
                    "provider": event.provider,
                    "model": event.model,
                    "latency_ms": event.latency_ms,
                    "audio_seconds": event.audio_seconds,
                },
            )
        )

    async def _handle_final_transcript(self, turn_id: str, event: TranscriptEvent) -> None:
        metrics = _stt_metrics_payload(event)
        metric = self.telemetry.turn(turn_id)
        metric.mark("stt_final")
        metric.counts["stt_audio_ms"] = round(event.audio_seconds * 1000)
        metric.statuses["stt_provider"] = event.provider
        metric.statuses["stt_model"] = event.model
        stt_cost, stt_source = stt_cost_micro_inr(
            provider=event.provider,
            audio_millis=metric.counts["stt_audio_ms"],
            card=self.telemetry.card,
        )
        metric.add_cost("stt", stt_cost, stt_source)
        status = "final"
        repeat_reason: str | None = None
        if not event.text:
            status = "empty"
            repeat_reason = "empty_transcript"
        elif event.confidence is not None and event.confidence < self.settings.stt_min_confidence:
            status = "low_confidence"
            repeat_reason = "low_confidence"

        coalesced = False
        coalesced_segments = 1
        effective_text = event.text
        pending_coalesced = self._pending_coalesced_turn
        if pending_coalesced is not None and repeat_reason is None and event.text:
            turn_id, previous_text = pending_coalesced
            effective_text = f"{previous_text} {event.text}".strip()
            coalesced = True
            coalesced_segments = 2
            self._pending_coalesced_turn = None

        await self.transport.publish_reliable(
            self.sequencer.encode(
                event_type="transcript_final",
                turn_id=turn_id,
                payload={
                    "text": effective_text,
                    "status": status,
                    "language": self.settings.language,
                    "confidence": event.confidence,
                    "coalesced": coalesced,
                    "coalesced_segments": coalesced_segments,
                    **metrics,
                },
            )
        )
        print(
            "stt_final",
            {
                "session_id": self.assignment.session_id,
                "turn_id": turn_id,
                **metrics,
                "empty": not event.text,
                "low_confidence": status == "low_confidence",
                "coalesced": coalesced,
                "coalesced_segments": coalesced_segments,
            },
            flush=True,
        )
        if repeat_reason is not None:
            await self._emit_transcript_repeat(turn_id, reason=repeat_reason, metrics=metrics)
            await self._emit_turn_metrics(turn_id, "retry_requested")
            return

        self.cancel_current_turn()
        self._active_response_turn_id = turn_id
        self._response_user_text[turn_id] = effective_text
        self._turn_stt_confidence[turn_id] = event.confidence
        self._turn_stt_metadata[turn_id] = (event.provider, event.model)
        self._response_committed_turns.discard(turn_id)
        self._current_turn = asyncio.create_task(
            self._respond_to_final_transcript(turn_id, effective_text)
        )

    async def _respond_to_final_transcript(self, turn_id: str, user_text: str) -> None:
        # Direct unit-test callers do not enter the turn scheduler. Real room
        # turns always have _current_turn set before this coroutine starts.
        if self._current_turn is None:
            self._active_response_turn_id = turn_id
        await self._emit_state("thinking", turn_id=turn_id)
        self.telemetry.turn(turn_id).mark("response_started")
        decision = self.safety_classifier.classify_input(user_text)
        if decision.response_override is not None:
            self._response_committed_turns.add(turn_id)
            await self._emit_assistant_final(
                turn_id,
                decision.response_override,
                status="safety_override",
                safety_reason=decision.reason,
                clipped=False,
                token=None,
            )
            self.context_builder.remember_complete_turn(
                turn_id,
                user_text,
                decision.response_override,
                assistant_status="safety_override",
            )
            await self._emit_state("listening", turn_id=turn_id, safety_reason=decision.reason)
            await self._emit_turn_metrics(turn_id, "safety_override")
            return

        memory_context = (
            await self._request_memory_context_v2(turn_id, user_text)
            if self._client_supports_memory_v2
            else {}
        )
        direct_text = _render_memory_directive(memory_context)
        direct_text = direct_text or _live_data_unavailable_response(user_text)
        turn_admission = _memory_admission_hint(memory_context)

        try:
            if direct_text is not None:
                text, clipped, last_token = direct_text, False, None
            else:
                policy_card = memory_context.get("policy_card")
                text, clipped, last_token = await self._stream_llm_response(
                    turn_id,
                    user_text,
                    policy_card=policy_card if isinstance(policy_card, dict) else None,
                    v2_memory_packets=memory_context.get("memory_packets")
                    if isinstance(memory_context.get("memory_packets"), list)
                    else None,
                    v2_semantic_resolved=memory_context.get("semantic_resolved") is True,
                    turn_admission=turn_admission,
                )
        except Exception as error:
            await self._emit_llm_error(turn_id, error)
            return

        output_decision = self.safety_classifier.classify_output(text)
        if output_decision.response_override is not None:
            text = output_decision.response_override
            clipped = False
        if self._active_response_turn_id != turn_id:
            return
        self._response_committed_turns.add(turn_id)
        await self._emit_assistant_final(
            turn_id,
            text,
            status="final",
            safety_reason=output_decision.reason or decision.reason,
            clipped=clipped,
            token=last_token,
        )
        self.context_builder.remember_complete_turn(turn_id, user_text, text)
        await self._speak_text(turn_id, text)
        await self._emit_state("listening", turn_id=turn_id)

    async def _stream_llm_response(
        self,
        turn_id: str,
        user_text: str,
        *,
        policy_card: dict[str, object] | None = None,
        v2_memory_packets: list[object] | None = None,
        v2_semantic_resolved: bool = False,
        turn_admission: dict[str, object] | None = None,
    ) -> tuple[str, bool, LLMToken | None]:
        messages = await self._llm_messages(
            turn_id,
            user_text,
            policy_card=policy_card,
            v2_memory_packets=v2_memory_packets,
            v2_semantic_resolved=v2_semantic_resolved,
            turn_admission=turn_admission,
        )
        metric = self.telemetry.turn(turn_id)
        metric.mark("llm_request_start")
        chunks: list[str] = []
        last_token: LLMToken | None = None
        async for token in self.llm_provider.stream(
            messages,
            self.settings.language,
            max_output_chars=self.persona.max_output_chars,
        ):
            if "llm_first_token" not in metric.timestamps_ms:
                metric.mark("llm_first_token")
            chunks.append(token.text)
            last_token = token
            partial = _sanitize_llm_output("".join(chunks).strip())
            if partial and not _looks_like_internal_marker_fragment(partial):
                await self._emit_assistant_partial(turn_id, partial, token)
        text = "".join(chunks).strip()
        text = _sanitize_llm_output(text)
        if not text:
            raise LLMProviderUnavailable("LLM stream did not include usable content.")
        if _is_question_turn(user_text) and _looks_like_question_echo(user_text, text):
            print(
                "llm_query_echo_guard",
                {
                    "session_id": self.assignment.session_id,
                    "turn_id": turn_id,
                    "user_chars": len(user_text),
                    "response_chars": len(text),
                },
                flush=True,
            )
            text = "Mujhe is baat ka abhi pakka jawab nahi pata."
        clipped_text, clipped = _clip_response_text(text, max_chars=self.persona.max_output_chars)
        metric.mark("llm_complete")
        if last_token is not None:
            input_tokens = last_token.input_tokens or _estimated_token_count(
                " ".join(message.content for message in messages)
            )
            output_tokens = last_token.output_tokens or _estimated_token_count(text)
            cost, source = llm_cost_micro_inr(
                provider=last_token.provider,
                model=last_token.model,
                input_tokens=input_tokens,
                cached_input_tokens=last_token.cached_input_tokens,
                output_tokens=output_tokens,
                card=self.telemetry.card,
                usage_reported=last_token.usage_reported,
            )
            metric.counts["llm_input_tokens"] = input_tokens
            metric.counts["llm_output_tokens"] = output_tokens
            metric.add_cost("llm", cost, source)
            metric.statuses["llm_usage"] = "reported" if last_token.usage_reported else "estimated"
        return clipped_text, clipped, last_token

    async def _request_memory_context_v2(
        self,
        turn_id: str,
        user_text: str,
    ) -> dict[str, object]:
        event = self.sequencer.next(
            event_type="memory_context_request_v2",
            turn_id=turn_id,
            schema_version=2,
            payload={
                "query_text": user_text,
                "language": self.settings.language,
                "transcript_status": "final",
                "stt_confidence": self._turn_stt_confidence.get(turn_id),
                "stt_provider": self._turn_stt_metadata.get(turn_id, ("", ""))[0],
                "stt_model": self._turn_stt_metadata.get(turn_id, ("", ""))[1],
                "max_blocks": 4,
                "memory_retrieval_strategy": self.memory_strategy.retrieval,
                "memory_reranker_strategy": self.memory_strategy.reranker,
            },
        )
        sequence = event["sequence"]
        if not isinstance(sequence, int):
            return {}
        future: asyncio.Future[dict[str, object]] = asyncio.get_running_loop().create_future()
        key = (turn_id, sequence)
        self._pending_memory_context_requests[key] = future
        await self.transport.publish_reliable(
            json.dumps(event, separators=(",", ":")).encode("utf-8")
        )
        try:
            return await asyncio.wait_for(future, self.settings.memory_lookup_timeout_seconds)
        except TimeoutError:
            metric = self.telemetry.turn(turn_id)
            metric.statuses["memory_fallback"] = "timeout"
            metric.counts["memory_timeout_count"] = metric.counts.get("memory_timeout_count", 0) + 1
            print(
                "memory_context_v2_timeout",
                {
                    "session_id": self.assignment.session_id,
                    "turn_id": turn_id,
                    "request_sequence": sequence,
                },
                flush=True,
            )
            return {}
        finally:
            self._pending_memory_context_requests.pop(key, None)

    async def _llm_messages(
        self,
        turn_id: str,
        user_text: str,
        *,
        policy_card: dict[str, object] | None = None,
        v2_memory_packets: list[object] | None = None,
        v2_semantic_resolved: bool = False,
        turn_admission: dict[str, object] | None = None,
    ) -> list[LLMMessage]:
        memory_route = route_memory_query(user_text)
        if (
            self.memory_strategy.planner == "qwen3_planner"
            and self.settings.enable_memory_planner
            and memory_route.route == "broad_safe"
            and memory_route.confidence < 0.6
        ):
            planned_route = await self.memory_planner.plan(user_text)
            if planned_route is not None:
                memory_route = planned_route
        turn_memory_packets: list[dict[str, object]] = []
        turn_memory_receipts: list[dict[str, object]] = []
        lookup_attempted = False
        if v2_semantic_resolved:
            lookup_attempted = True
            turn_memory_packets = [
                packet for packet in (v2_memory_packets or []) if isinstance(packet, dict)
            ][:6]
        elif memory_route.route not in {"none", "safety"} and memory_route.max_blocks > 0:
            lookup_attempted = True
            turn_memory_packets, turn_memory_receipts = await self._lookup_turn_memory(
                turn_id,
                user_text,
                memory_route,
            )
        messages, diagnostics = self.context_builder.build(
            user_text,
            turn_memory_packets=turn_memory_packets,
            turn_memory_receipts=turn_memory_receipts,
            companion_policy=policy_card,
            turn_admission=turn_admission,
        )
        lookup_latency_ms = self._memory_lookup_latency_ms.pop(turn_id, None)
        metric = self.telemetry.turn(turn_id)
        metric.mark("memory_lookup_complete")
        metric.statuses["memory_route"] = memory_route.route
        metric.statuses["memory_retrieval_strategy"] = self.memory_strategy.retrieval
        metric.statuses["memory_reranker_strategy"] = self.memory_strategy.reranker
        metric.statuses["memory_planner_strategy"] = self.memory_strategy.planner
        metric.statuses["memory_needed"] = "yes" if lookup_attempted else "no"
        metric.counts["memory_candidates_returned"] = len(turn_memory_packets)
        metric.counts["memory_candidates_injected"] = diagnostics["memory_blocks_selected"]
        if lookup_latency_ms is not None:
            metric.durations_ms["memory_lookup"] = lookup_latency_ms
        print(
            "memory_lookup_metrics",
            {
                "session_id": self.assignment.session_id,
                "turn_id": turn_id,
                "route": memory_route.route,
                "lookup_attempted": lookup_attempted,
                "lookup_latency_ms": lookup_latency_ms,
                "candidates_returned": len(turn_memory_packets),
                "candidates_injected": diagnostics["memory_blocks_selected"],
                "no_memory_decision": not turn_memory_packets,
                "turn_admission_present": turn_admission is not None,
                "context_char_budget": self.context_builder.max_context_chars,
                "context_chars": diagnostics["context_chars"],
                "retrieval_strategy": self.memory_strategy.retrieval,
                "reranker_strategy": self.memory_strategy.reranker,
                "planner_strategy": self.memory_strategy.planner,
            },
            flush=True,
        )
        print(
            "prompt_context",
            {
                "session_id": self.assignment.session_id,
                "memory_route": memory_route.route,
                "memory_route_confidence": memory_route.confidence,
                "memory_route_reason": memory_route.reason,
                "memory_retrieval_strategy": self.memory_strategy.retrieval,
                "memory_reranker_strategy": self.memory_strategy.reranker,
                "memory_planner_strategy": self.memory_strategy.planner,
                **diagnostics,
            },
            flush=True,
        )
        return messages

    async def _lookup_turn_memory(
        self,
        turn_id: str,
        user_text: str,
        memory_route: MemoryRoutingDecision,
    ) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
        event = self.sequencer.next(
            event_type="memory_lookup_request",
            turn_id=turn_id,
            payload={
                "query_text": user_text,
                "route": memory_route.route,
                "route_confidence": memory_route.confidence,
                "route_reason": memory_route.reason,
                "max_blocks": memory_route.max_blocks,
                "memory_retrieval_strategy": self.memory_strategy.retrieval,
                "memory_reranker_strategy": self.memory_strategy.reranker,
            },
        )
        sequence = event["sequence"]
        if not isinstance(sequence, int):
            return []
        loop = asyncio.get_running_loop()
        future: asyncio.Future[tuple[list[dict[str, object]], list[dict[str, object]]]] = (
            loop.create_future()
        )
        key = (turn_id, sequence)
        self._pending_memory_requests[key] = future
        await self.transport.publish_reliable(
            json.dumps(event, separators=(",", ":")).encode("utf-8")
        )
        try:
            return await asyncio.wait_for(future, self.settings.memory_lookup_timeout_seconds)
        except TimeoutError:
            metric = self.telemetry.turn(turn_id)
            metric.statuses["memory_fallback"] = "timeout"
            metric.counts["memory_timeout_count"] = metric.counts.get("memory_timeout_count", 0) + 1
            print(
                "memory_lookup_timeout",
                {
                    "session_id": self.assignment.session_id,
                    "turn_id": turn_id,
                    "request_sequence": sequence,
                    "memory_route": memory_route.route,
                    "timeout_ms": round(self.settings.memory_lookup_timeout_seconds * 1000),
                },
                flush=True,
            )
            return [], []
        finally:
            self._pending_memory_requests.pop(key, None)

    async def _handle_client_data_event(self, activity: str) -> bool:
        try:
            event = json.loads(activity)
        except json.JSONDecodeError:
            return False
        if not isinstance(event, dict):
            return False

        if event.get("type") == "client_session_started":
            versions = event.get("memory_protocol_versions")
            self._client_supports_memory_v2 = (
                isinstance(versions, list) and 2 in versions
            ) or event.get("schema_version") == 2
            return True

        if event.get("type") == "client_playback_started":
            turn_id = event.get("turn_id")
            client_timestamp = event.get("playback_timestamp_ms")
            if (
                isinstance(turn_id, str)
                and isinstance(client_timestamp, int)
                and client_timestamp >= 0
            ):
                metric = self.telemetry.turn(turn_id)
                metric.timestamps_ms["client_first_playback_timestamp_ms"] = client_timestamp
                metric.mark("server_received_client_playback")
                metric.statuses["playback_correlation"] = "reported"
            return True

        if event.get("type") == "memory_judge_notice":
            turn_id = event.get("turn_id")
            notice = event.get("notice")
            if not isinstance(turn_id, str) or not isinstance(notice, str) or not notice.strip():
                return True
            notice_id = event.get("notice_id")
            if isinstance(notice_id, str) and notice_id:
                if notice_id in self._relayed_memory_notice_ids:
                    # Reconnect/replay duplicate: the user already saw this
                    # notice and its operation record already exists.
                    return True
                self._relayed_memory_notice_ids.add(notice_id)
            allowed_outcomes = {
                "accepted",
                "superseded",
                "rejected",
                "unavailable",
                "timeout",
                "invalid",
            }
            outcome = event.get("outcome")
            if outcome not in allowed_outcomes:
                outcome = "invalid"
            # Extraction completes after the voice turn. Relay this on the
            # reliable channel only: creating another assistant/TTS response
            # here can overlap or corrupt a response already in progress.
            await self.transport.publish_reliable(
                self.sequencer.encode(
                    event_type="memory_judge_notice",
                    turn_id=turn_id,
                    payload={
                        "notice": notice.strip(),
                        "notice_id": notice_id,
                        "outcome": outcome,
                        "accepted_count": _bounded_int(event.get("accepted_count")),
                        "window_turn_count": _bounded_int(event.get("window_turn_count")),
                        "attempt_count": _bounded_int(event.get("attempt_count")),
                        "request_started_at_ms": _bounded_int(event.get("request_started_at_ms")),
                        "completed_at_ms": _bounded_int(event.get("completed_at_ms")),
                    },
                )
            )
            # A later memory judgement appends an immutable operation record.
            # It never touches or re-emits the terminal voice-turn envelope,
            # and it carries no notice text or content.
            cost_source = event.get("cost_source")
            if cost_source not in {"provider_reported", "estimated", "unknown"}:
                # An unpriced/unlabelled external judge dependency stays
                # unknown/cost-incomplete rather than silently zero.
                cost_source = "unknown"
            envelope = self.telemetry.memory_judge_operation(
                turn_id,
                outcome=str(outcome),
                accepted_count=_bounded_int(event.get("accepted_count")),
                window_turn_count=_bounded_int(event.get("window_turn_count")),
                attempt_count=_bounded_int(event.get("attempt_count")),
                request_started_at_ms=_bounded_int(event.get("request_started_at_ms")),
                completed_at_ms=_bounded_int(event.get("completed_at_ms")),
                cost_source=cost_source,
                cost_micro_inr=_bounded_int(event.get("estimated_micro_inr")),
                input_tokens=_bounded_int(event.get("input_tokens")),
                output_tokens=_bounded_int(event.get("output_tokens")),
            )
            if isinstance(notice_id, str) and notice_id:
                envelope["record_id"] = (
                    f"{self.assignment.session_id}:{turn_id}:memory_judge:{notice_id}"
                )
            await self._publish_telemetry_envelope(turn_id, envelope)
            return True

        if event.get("type") == "memory_context_response_v2":
            return self._handle_memory_context_response_v2(event)
        if event.get("type") != "memory_lookup_response":
            return False

        turn_id = event.get("turn_id")
        request_sequence = event.get("request_sequence")
        if not isinstance(turn_id, str) or not isinstance(request_sequence, int):
            return True

        key = (turn_id, request_sequence)
        future = self._pending_memory_requests.get(key)
        if future is None or future.done():
            print(
                "memory_lookup_stale_response",
                {
                    "session_id": self.assignment.session_id,
                    "turn_id": turn_id,
                    "request_sequence": request_sequence,
                },
                flush=True,
            )
            return True

        raw_packets = event.get("memory_packets", [])
        packets = (
            [packet for packet in raw_packets if isinstance(packet, dict)][:6]
            if isinstance(raw_packets, list)
            else []
        )
        raw_receipts = event.get("pending_receipts", [])
        receipts = (
            [receipt for receipt in raw_receipts if isinstance(receipt, dict)][:1]
            if isinstance(raw_receipts, list)
            else []
        )
        elapsed_ms = event.get("elapsed_ms")
        if isinstance(elapsed_ms, int) and elapsed_ms >= 0:
            self._memory_lookup_latency_ms[turn_id] = elapsed_ms
        future.set_result((packets, receipts))
        print(
            "memory_lookup_response",
            {
                "session_id": self.assignment.session_id,
                "turn_id": turn_id,
                "request_sequence": request_sequence,
                "elapsed_ms": event.get("elapsed_ms"),
                "memory_packets": len(packets),
                "pending_receipts": len(receipts),
            },
            flush=True,
        )
        return True

    def _handle_memory_context_response_v2(self, event: dict[str, object]) -> bool:
        turn_id = event.get("turn_id")
        request_sequence = event.get("request_sequence")
        if not isinstance(turn_id, str) or not isinstance(request_sequence, int):
            return True
        future = self._pending_memory_context_requests.get((turn_id, request_sequence))
        if future is None or future.done():
            print(
                "memory_context_v2_stale_response",
                {
                    "session_id": self.assignment.session_id,
                    "turn_id": turn_id,
                    "request_sequence": request_sequence,
                },
                flush=True,
            )
            return True
        result = {
            "response_directive": event.get("response_directive"),
            "state_facts": event.get("state_facts"),
            "pending_candidate": event.get("pending_candidate"),
            "policy_card": event.get("policy_card"),
            "memory_packets": event.get("memory_packets"),
            "semantic_resolved": event.get("semantic_resolved"),
        }
        elapsed_ms = event.get("elapsed_ms")
        if isinstance(elapsed_ms, int) and elapsed_ms >= 0:
            self._memory_lookup_latency_ms[turn_id] = elapsed_ms
        future.set_result(result)
        print(
            "memory_context_v2_response",
            {
                "session_id": self.assignment.session_id,
                "turn_id": turn_id,
                "request_sequence": request_sequence,
                "directive": event.get("response_directive"),
                "state_fact_count": len(event.get("state_facts", []))
                if isinstance(event.get("state_facts"), list)
                else 0,
            },
            flush=True,
        )
        return True

    async def _emit_assistant_partial(
        self,
        turn_id: str,
        text: str,
        token: LLMToken,
    ) -> None:
        await self.transport.publish_lossy(
            self.sequencer.encode(
                event_type="assistant_transcript_partial",
                turn_id=turn_id,
                payload={
                    "text": text,
                    "language": self.settings.language,
                    "provider": token.provider,
                    "model": token.model,
                    "latency_ms": token.latency_ms,
                },
            )
        )

    async def _emit_assistant_final(
        self,
        turn_id: str,
        text: str,
        *,
        status: str,
        safety_reason: str | None,
        clipped: bool,
        token: LLMToken | None,
    ) -> None:
        payload: dict[str, object] = {
            "text": text,
            "status": status,
            "language": self.settings.language,
            "provider": token.provider if token is not None else "safety",
            "model": token.model if token is not None else "crisis_override",
            "latency_ms": token.latency_ms if token is not None else 0,
            "billed_units": token.billed_units if token is not None else 0,
            "cost_units": token.cost_units if token is not None else 0,
            "clipped": clipped,
        }
        if safety_reason is not None:
            payload["safety_reason"] = safety_reason
        await self.transport.publish_reliable(
            self.sequencer.encode(
                event_type="assistant_transcript_final",
                turn_id=turn_id,
                payload=payload,
            )
        )

    async def _speak_text(self, turn_id: str, text: str) -> None:
        await self._emit_state("speaking", turn_id=turn_id)
        started = _monotonic_ms()
        metric = self.telemetry.turn(turn_id)
        metric.mark("tts_request_start")
        first_audio_ms: int | None = None
        totals = {
            "chars": 0,
            "audio_ms": 0,
            "billed_units": 0.0,
            "cost_units": 0.0,
        }
        provider = selected_tts_provider_name(self.settings, language=self.assignment.language)
        model = self.settings.tts_model
        try:
            async for tts_frame in self.tts_provider.synthesize(text, self.assignment.language):
                if first_audio_ms is None:
                    first_audio_ms = _monotonic_ms() - started
                    metric.mark("tts_first_audio")
                    await self.transport.publish_reliable(
                        self.sequencer.encode(
                            event_type="tts_playback_marker",
                            turn_id=turn_id,
                            payload={"audio_format": _audio_format_payload(tts_frame.frame)},
                        )
                    )
                _add_tts_totals(totals, tts_frame)
                if tts_frame.chars:
                    amount, source = tts_cost_micro_inr(
                        model=tts_frame.model or model,
                        billed_chars=tts_frame.chars,
                        card=self.telemetry.card,
                    )
                    metric.add_cost("tts", amount, source)
                provider = tts_frame.provider or provider
                model = tts_frame.model or model
                await self.transport.publish_audio_frame(tts_frame.frame)
                if "tts_first_published" not in metric.timestamps_ms:
                    metric.mark("tts_first_published")
            if isinstance(self.tts_provider, FailoverTTSProvider):
                for fallback_event in self.tts_provider.drain_fallback_events():
                    provider = str(fallback_event["to"])
                    metric.statuses["tts_fallback_reason"] = str(fallback_event["reason"])
                    metric.statuses["tts_fallback_provider"] = provider
                    metric.counts["tts_fallback_count"] = (
                        metric.counts.get("tts_fallback_count", 0) + 1
                    )
                    if fallback_event["audio_started"]:
                        metric.statuses["tts_status"] = "partial_primary_failure"
                    await self.transport.publish_reliable(
                        self.sequencer.encode(
                            event_type="tts_provider_changed",
                            turn_id=turn_id,
                            payload={
                                **fallback_event,
                                "voice_id": self.assignment.voice_id,
                            },
                        )
                    )
        except asyncio.CancelledError:
            await self.transport.stop_audio(fade_out_ms=60)
            metric.mark("cancel_complete")
            metric.statuses["tts_status"] = "cancelled_cost_uncertain"
            await self._emit_turn_metrics(turn_id, "cancelled")
            raise
        except Exception as error:
            await self._emit_tts_error(turn_id, str(error))
            metric.statuses["tts_status"] = "error"
            await self._emit_turn_metrics(turn_id, "tts_error")
            print(
                "tts_error",
                {
                    "session_id": self.assignment.session_id,
                    "turn_id": turn_id,
                    "provider": provider,
                    "error_code": _error_code(error),
                },
                flush=True,
            )
            return

        latency_ms = _monotonic_ms() - started
        metrics = {
            "provider": provider,
            "model": model,
            "latency_ms": latency_ms,
            "first_audio_ms": first_audio_ms or latency_ms,
            **totals,
        }
        await self._emit_tts_metrics(turn_id, metrics)
        metric.mark("tts_complete")
        metric.counts["tts_chars"] = int(totals["chars"])
        metric.counts["tts_audio_ms"] = int(totals["audio_ms"])
        metric.statuses["tts_provider"] = provider
        metric.statuses["tts_model"] = model
        await self._emit_turn_metrics(turn_id, "completed")
        print(
            "tts_final",
            {"session_id": self.assignment.session_id, "turn_id": turn_id, **metrics},
            flush=True,
        )

    async def _emit_tts_metrics(self, turn_id: str, metrics: dict[str, object]) -> None:
        await self.transport.publish_reliable(
            self.sequencer.encode(event_type="tts_metrics", turn_id=turn_id, payload=metrics)
        )

    async def _emit_turn_metrics(self, turn_id: str, outcome: str) -> None:
        envelope = self.telemetry.terminal(turn_id, outcome)
        await self._publish_telemetry_envelope(turn_id, envelope)

    async def _publish_telemetry_envelope(
        self, turn_id: str, envelope: dict[str, object]
    ) -> None:
        await self.transport.publish_reliable(
            self.sequencer.encode(event_type="turn_metrics", turn_id=turn_id, payload=envelope)
        )
        print("turn_metrics_final", envelope, flush=True)
        if self.settings.enable_metrics_ingest and self.settings.metrics_ingest_token:
            try:
                async with httpx.AsyncClient(timeout=1.0) as client:
                    await client.post(
                        self.settings.metrics_ingest_url,
                        headers={"x-telemetry-ingest-token": self.settings.metrics_ingest_token},
                        json={"envelope": envelope},
                    )
            except httpx.HTTPError:
                # Metrics must never affect the voice turn. The local data event remains exportable.
                print("telemetry_ingest_failed", {"turn_id": turn_id}, flush=True)

    async def _emit_tts_error(self, turn_id: str, message: str) -> None:
        await self.transport.publish_reliable(
            self.sequencer.encode(
                event_type="tts_error",
                turn_id=turn_id,
                payload={
                    "error_code": _error_code(message),
                    "provider": selected_tts_provider_name(
                        self.settings, language=self.assignment.language
                    ),
                },
            )
        )

    async def _emit_transcript_repeat(
        self,
        turn_id: str,
        *,
        reason: str,
        metrics: dict[str, object],
    ) -> None:
        await self.transport.publish_reliable(
            self.sequencer.encode(
                event_type="transcript_repeat_requested",
                turn_id=turn_id,
                payload={
                    "reason": reason,
                    "message": "I did not catch that clearly. Please say it again.",
                    **metrics,
                },
            )
        )
        print(
            "stt_repeat_requested",
            {"session_id": self.assignment.session_id, "turn_id": turn_id, "reason": reason},
            flush=True,
        )
        await self._emit_state("listening", turn_id=turn_id)

    async def _emit_stt_error(self, turn_id: str, message: str) -> None:
        await self.transport.publish_reliable(
            self.sequencer.encode(
                event_type="stt_error",
                turn_id=turn_id,
                payload={
                    "error_code": _error_code(message),
                    "provider": selected_stt_provider_name(self.settings),
                },
            )
        )
        print(
            "stt_error",
            {
                "session_id": self.assignment.session_id,
                "turn_id": turn_id,
                "error_code": _error_code(message),
            },
            flush=True,
        )
        self.telemetry.turn(turn_id).statuses["stt_status"] = "error"
        await self._emit_turn_metrics(turn_id, "stt_error")
        await self._emit_state("listening", turn_id=turn_id)

    async def _emit_llm_error(self, turn_id: str, error: Exception) -> None:
        provider = selected_llm_provider_name(self.settings)
        await self.transport.publish_reliable(
            self.sequencer.encode(
                event_type="llm_error",
                turn_id=turn_id,
                payload={
                    "error_code": _error_code(error),
                    "provider": provider,
                    # This is a UI-only operational message, never an assistant
                    # reply, transcript, memory input, or TTS payload.
                    "message": "AI response is temporarily unavailable. Please try again.",
                },
            )
        )
        print(
            "llm_error",
            {
                "session_id": self.assignment.session_id,
                "turn_id": turn_id,
                "provider": provider,
                "error_code": _error_code(error),
            },
            flush=True,
        )
        self.telemetry.turn(turn_id).statuses["llm_status"] = "error"
        await self._emit_turn_metrics(turn_id, "llm_error")
        await self._emit_state("listening", turn_id=turn_id)


class AgentSupervisor:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._tasks: dict[str, asyncio.Task[None]] = {}

    async def assign(self, assignment: AgentAssignment) -> None:
        self._reap_finished()
        if assignment.session_id in self._tasks:
            return
        if len(self._tasks) >= self.settings.max_concurrent_agents:
            raise AgentAssignmentError("maximum concurrent agents reached")

        transport: AgentTransport = LiveKitAgentTransport(
            assignment=assignment,
            settings=self.settings,
        )
        session = RealtimeAgentSession(
            assignment=assignment,
            settings=self.settings,
            transport=transport,
        )
        task = asyncio.create_task(session.run(), name=f"agent:{assignment.session_id}")
        self._tasks[assignment.session_id] = task

        try:
            await asyncio.wait_for(_wait_until_started(task, session.started), timeout=3.0)
        except Exception:
            task.cancel()
            self._tasks.pop(assignment.session_id, None)
            raise

    def cancel(self, session_id: str) -> bool:
        task = self._tasks.get(session_id)
        if task is None or task.done():
            return False
        task.cancel()
        return True

    def active_count(self) -> int:
        self._reap_finished()
        return len(self._tasks)

    def _reap_finished(self) -> None:
        for session_id, task in list(self._tasks.items()):
            if task.done():
                self._tasks.pop(session_id, None)


class _STTTurnStream:
    def __init__(self, *, turn_id: str) -> None:
        self.turn_id = turn_id
        self.task: asyncio.Task[None] | None = None
        self._queue: asyncio.Queue[CanonicalAudioFrame | None] = asyncio.Queue()

    def push(self, frame: CanonicalAudioFrame) -> None:
        self._queue.put_nowait(frame)

    def close(self) -> None:
        self._queue.put_nowait(None)

    async def frames(self) -> AsyncIterator[CanonicalAudioFrame]:
        while True:
            frame = await self._queue.get()
            if frame is None:
                return
            yield frame


def create_stt_provider(settings: Settings) -> STTProvider:
    provider_name = selected_stt_provider_name(settings)
    try:
        if provider_name == "mock":
            return MockSTTProvider()
        if provider_name == "vosk":
            return VoskSTTProvider(
                model_path=settings.vosk_model_path,
                model_name=settings.stt_model,
            )
        if provider_name == "sarvam":
            return SarvamSTTProvider(
                api_key=settings.sarvam_api_key,
                model=settings.sarvam_stt_model,
                mode=settings.sarvam_stt_mode,
                chunk_ms=settings.sarvam_stt_chunk_ms,
                response_timeout_seconds=settings.sarvam_stt_response_timeout_seconds,
                price_per_hour=settings.sarvam_stt_price_per_hour,
            )
        raise AgentAssignmentError(f"Unsupported STT provider: {provider_name}")
    except Exception as error:
        return _UnavailableSTTProvider(provider_name=provider_name, error=error)


def create_llm_provider(settings: Settings) -> LLMProvider:
    provider_name = selected_llm_provider_name(settings)
    try:
        if provider_name == "sarvam":
            return SarvamChatLLMProvider(
                api_key=settings.sarvam_api_key,
                model=settings.llm_model,
                base_url=settings.sarvam_base_url,
                timeout_seconds=settings.llm_timeout_seconds,
            )
        if provider_name == "mock" and settings.environment != "production":
            return MockLLMProvider()
        if provider_name == "mock":
            raise AgentAssignmentError("The mock LLM provider is not allowed in production.")
        raise AgentAssignmentError(f"Unsupported LLM provider: {provider_name}")
    except Exception as error:
        return _UnavailableLLMProvider(provider_name=provider_name, error=error)


def create_tts_provider(
    settings: Settings,
    *,
    language: str | None = None,
    voice_id: str | None = None,
) -> TTSProvider:
    resolved_language = language or settings.language
    provider_name = selected_tts_provider_name(settings, language=resolved_language)
    fallback_name = selected_tts_fallback_provider_name(settings, language=resolved_language)
    try:
        catalog = load_voice_catalog(settings.voice_catalog)
        profile = catalog.require(voice_id)
        if resolved_language != catalog.language:
            raise AgentAssignmentError(f"Unsupported TTS language: {resolved_language}")

        def build(name: str) -> TTSProvider:
            if name == "mock":
                return MockTTSProvider()
            if name == "kokoro":
                return KokoroTTSProvider(
                    base_url=settings.kokoro_base_url,
                    model=settings.kokoro_model,
                    voice=profile.kokoro_voice,
                    sample_rate=settings.tts_sample_rate,
                    first_audio_timeout_seconds=settings.kokoro_first_audio_timeout_seconds,
                    total_timeout_seconds=settings.kokoro_total_timeout_seconds,
                )
            if name == "sarvam":
                return SarvamBulbulTTSProvider(
                    api_key=settings.sarvam_api_key,
                    model=settings.tts_model,
                    base_url=settings.sarvam_tts_base_url,
                    speaker=profile.sarvam_fallback_speaker,
                    sample_rate=settings.tts_sample_rate,
                    timeout_seconds=settings.tts_timeout_seconds,
                    price_per_10k_chars=settings.tts_price_per_10k_chars,
                )
            raise AgentAssignmentError(f"Unsupported TTS provider: {name}")

        primary = build(provider_name)
        if fallback_name and fallback_name != provider_name:
            return FailoverTTSProvider(
                primary=primary,
                fallback=build(fallback_name),
                primary_name=provider_name,
                fallback_name=fallback_name,
            )
        return primary
    except Exception as error:
        return _UnavailableTTSProvider(provider_name=provider_name, error=error)


def selected_llm_provider_name(settings: Settings) -> str:
    if settings.llm_provider:
        return settings.llm_provider
    try:
        routing = ProviderRouting.from_dict(_load_persona_config(settings))
        return routing.for_language(settings.language).llm
    except Exception:
        return "sarvam"


def selected_stt_provider_name(settings: Settings) -> str:
    if settings.stt_provider:
        return settings.stt_provider
    try:
        routing = ProviderRouting.from_dict(_load_persona_config(settings))
        return routing.for_language(settings.language).stt
    except Exception:
        return "vosk"


def selected_tts_provider_name(settings: Settings, *, language: str | None = None) -> str:
    if settings.tts_provider:
        return settings.tts_provider
    try:
        routing = ProviderRouting.from_dict(_load_persona_config(settings))
        return routing.for_language(language or settings.language).tts
    except Exception:
        return "mock"


def selected_tts_fallback_provider_name(settings: Settings, *, language: str | None = None) -> str:
    if settings.tts_fallback_provider:
        return settings.tts_fallback_provider
    if settings.tts_provider:
        return ""
    try:
        routing = ProviderRouting.from_dict(_load_persona_config(settings))
        return routing.for_language(language or settings.language).tts_fallback
    except Exception:
        return ""


def selected_memory_strategy(settings: Settings) -> MemoryStrategyRoute:
    try:
        routing = ProviderRouting.from_dict(_load_persona_config(settings))
        strategy = routing.memory_for_language(settings.language)
        if strategy.retrieval not in {"deterministic", "hybrid_vector"}:
            raise ValueError("unsupported memory retrieval strategy")
        if strategy.reranker not in {"deterministic", "qwen3_reranker"}:
            raise ValueError("unsupported memory reranker strategy")
        if strategy.planner not in {"deterministic", "qwen3_planner"}:
            raise ValueError("unsupported memory planner strategy")
        return strategy
    except Exception:
        return MemoryStrategyRoute(
            retrieval="deterministic",
            reranker="deterministic",
            planner="deterministic",
        )


def _load_persona_config(settings: Settings) -> dict[str, object]:
    import tomllib
    from pathlib import Path

    path = Path(settings.persona_config)
    if not path.is_absolute():
        for parent in Path(__file__).resolve().parents:
            if (parent / "config" / "personas").is_dir():
                path = parent / path
                break
    with path.open("rb") as file:
        data = tomllib.load(file)
    return data


def _stt_metrics_payload(event: TranscriptEvent) -> dict[str, object]:
    return {
        "provider": event.provider,
        "model": event.model,
        "latency_ms": event.latency_ms,
        "audio_seconds": event.audio_seconds,
        "billed_units": event.billed_units,
        "cost_units": event.cost_units,
    }


def _add_tts_totals(totals: dict[str, float], frame: TTSAudioFrame) -> None:
    totals["chars"] += frame.chars
    totals["audio_ms"] += frame.audio_ms
    totals["billed_units"] += frame.billed_units
    totals["cost_units"] += frame.cost_units


def _audio_format_payload(frame: CanonicalAudioFrame) -> dict[str, object]:
    """Format-only diagnostic; audio samples must never reach telemetry."""
    return {
        "codec": "pcm_s16le",
        "sample_rate_hz": frame.sample_rate,
        "channels": frame.num_channels,
        "frame_duration_ms": frame.duration_ms,
    }


def _estimated_token_count(text: str) -> int:
    """Conservative, versioned fallback when a provider omits usage metadata."""
    return max((len(text.strip()) + 3) // 4, 0)


def _bounded_int(value: object, *, maximum: int = 10_000_000_000) -> int:
    """Redacted counter coercion: non-negative bounded integers only."""
    if isinstance(value, bool) or not isinstance(value, int):
        return 0
    return min(max(value, 0), maximum)


def _error_code(error: object) -> str:
    """Safe operational classification; provider exception text can contain content."""
    name = type(error).__name__ if not isinstance(error, str) else "provider_error"
    return "".join(
        character for character in name.lower() if character.isalnum() or character == "_"
    )[:64]


def _clip_response_text(text: str, *, max_chars: int) -> tuple[str, bool]:
    if len(text) <= max_chars:
        return text, False
    boundary = max(text.rfind(marker, 0, max_chars) for marker in (".", "?", "!", "।"))
    if boundary < max_chars // 2:
        boundary = text.rfind(" ", 0, max_chars)
    if boundary <= 0:
        boundary = max_chars
    return text[:boundary].strip(), True


_INTERNAL_CONTEXT_MARKERS = (
    "[recent_turns]",
    "[latest_user]",
    "[core_profile]",
    "[procedural_memory]",
    "[semantic_memory]",
    "[episodic_memory]",
    "[session_summary]",
    "[memory_receipt]",
)


def _sanitize_llm_output(text: str) -> str:
    sanitized = text
    for marker in _INTERNAL_CONTEXT_MARKERS:
        sanitized = sanitized.replace(marker, "")
    return " ".join(sanitized.split()).strip()


def _looks_like_internal_marker_fragment(text: str) -> bool:
    lowered = text.casefold()
    return any(
        fragment in lowered
        for fragment in (
            "[recent",
            "[latest",
            "[core",
            "[procedural",
            "[semantic",
            "[episodic",
            "[session",
            "[memory",
        )
    )


def _looks_like_question_echo(user_text: str, response_text: str) -> bool:
    """Catch the narrow failure where the model returns the user's question."""
    user_tokens = _response_tokens(user_text)
    response_tokens = _response_tokens(response_text)
    if len(user_tokens) < 2 or len(response_tokens) < 2:
        return False
    overlap = len(user_tokens & response_tokens) / len(user_tokens)
    response_is_question = any(
        mark in response_text for mark in ("?", "？", "क्या", "कौन", "कैसे", "कब", "कहाँ")
    )
    return response_is_question and overlap >= 0.65 and len(response_tokens) <= len(user_tokens) + 5


def _is_question_turn(text: str) -> bool:
    lowered = text.casefold()
    return any(
        marker in lowered
        for marker in ("?", "क्या", "कौन", "कैसे", "किस", "kya", "kaun", "kaise", "kis")
    )


def _render_memory_directive(context: dict[str, object]) -> str | None:
    directive = context.get("response_directive")
    facts = context.get("state_facts")
    fact = facts[0] if isinstance(facts, list) and facts and isinstance(facts[0], dict) else None
    if directive == "fact_unknown":
        return "मुझे यह बात अभी याद नहीं है।"
    # Interactive memory receipts are intentionally disabled. Ambiguous source
    # material is judged by the bounded extraction path or dropped, never
    # surfaced as a confirmation question during a companion conversation.
    if directive == "confirmation":
        return None
    if fact is None:
        return None
    value = fact.get("value")
    state_key = fact.get("state_key")
    text = value.get("text") if isinstance(value, dict) else None
    if not isinstance(text, str) or not isinstance(state_key, str):
        return None
    if directive == "fact_answer":
        if state_key == "user.profile.preferred_name":
            return f"आपका नाम {text} है।"
        if state_key.startswith("user.relationship.brother."):
            return f"आपके भाई का नाम {text} है।"
        if state_key.startswith("user.relationship.sister."):
            return f"आपकी बहन का नाम {text} है।"
        if state_key == "user.preference.response_language":
            return f"आपको {_spoken_language(text)} में जवाब पसंद हैं।"
        if state_key == "user.preference.response_length":
            return "आपको छोटे जवाब पसंद हैं।"
        if state_key == "user.preference.comfort_style":
            return "आपको सलाह देने से पहले बस सुनना पसंद है।"
        if state_key.startswith("user.routine.morning."):
            return "आप रोज सुबह टहलते हैं।"
        if state_key.startswith("user.boundary."):
            return "आप इस विषय पर बात नहीं करना पसंद करते हैं।"
        if state_key.startswith("user.goal."):
            return f"आपका लक्ष्य {text} है।"
    if directive == "setting_ack":
        if state_key == "user.preference.response_language":
            return f"ठीक है, मैं {_spoken_language(text)} में जवाब दूँगा।"
        if state_key == "user.preference.response_length":
            return "ठीक है, मैं छोटे जवाब दूँगा।"
        if state_key == "user.preference.comfort_style":
            return "ठीक है, मैं सलाह देने से पहले आपकी बात सुनूँगा। मैं सुन रहा हूँ।"
        if state_key == "user.profile.preferred_name":
            return None
        if state_key.startswith("user.relationship."):
            return None
        if state_key.startswith("user.routine."):
            return None
        if state_key.startswith("user.boundary."):
            return "ठीक है, मैं राजनीति से बचूँगा। हम किसी और बात पर बात कर सकते हैं।"
        if state_key.startswith("user.goal."):
            return None
    return None


def _memory_admission_hint(context: dict[str, object]) -> dict[str, object] | None:
    if context.get("response_directive") != "setting_ack":
        return None
    facts = context.get("state_facts")
    fact = facts[0] if isinstance(facts, list) and facts and isinstance(facts[0], dict) else None
    if fact is None:
        return None
    state_key = fact.get("state_key")
    value = fact.get("value")
    text = value.get("text") if isinstance(value, dict) else None
    if not isinstance(state_key, str) or not isinstance(text, str):
        return None
    if state_key == "user.profile.preferred_name":
        return {"kind": "preferred_name", "user_name": text}
    if state_key.startswith("user.relationship.brother."):
        return {"kind": "relationship", "relationship_role": "brother", "person_name": text}
    if state_key.startswith("user.relationship.sister."):
        return {"kind": "relationship", "relationship_role": "sister", "person_name": text}
    if state_key.startswith("user.routine.morning."):
        return {"kind": "morning_walk"}
    if state_key.startswith("user.goal."):
        return {"kind": "goal", "goal": text}
    return None


def _confirmation_text(state_key: str, text: str) -> str:
    if state_key == "user.profile.preferred_name":
        return f"आपने बताया कि आपका नाम {text} है। क्या मैं आपको {text} कहूँ? आज आपका दिन कैसा रहा?"
    if state_key.startswith("user.relationship."):
        role = "बहन" if ".sister." in state_key else "भाई"
        return f"आपने बताया कि आपके {role} का नाम {text} है। क्या मैं यह याद रखूँ? आप दोनों कैसे हैं?"
    if state_key.startswith("user.routine."):
        return "आप रोज सुबह टहलते हैं। क्या मैं यह याद रखूँ? टहलने के बाद आपको कैसा लगता है?"
    if state_key == "user.preference.comfort_style":
        return "आप चाहते हैं कि मैं सलाह से पहले आपकी बात सुनूँ। क्या मैं यह याद रखूँ? मैं सुन रहा हूँ।"
    if state_key == "user.preference.response_language":
        return f"आप {_spoken_language(text)} में जवाब चाहते हैं। क्या मैं यह याद रखूँ? बताइए, अभी आपके मन में क्या है?"
    if state_key == "user.preference.response_length":
        return "आप छोटे जवाब चाहते हैं। क्या मैं यह याद रखूँ?"
    if state_key.startswith("user.boundary."):
        return "आप चाहते हैं कि मैं राजनीति से बचूँ। क्या मैं यह याद रखूँ? हम किसी और बात पर बात कर सकते हैं।"
    if state_key.startswith("user.goal."):
        return f"आपका लक्ष्य {text} है। क्या मैं यह याद रखूँ? आज यह कैसा चल रहा है?"
    return "क्या आप चाहते हैं कि मैं यह बात याद रखूँ?"


def _spoken_language(value: str) -> str:
    return {"Hindi": "हिंदी", "English": "अंग्रेज़ी", "Hinglish": "हिंग्लिश"}.get(
        value,
        value,
    )


def _live_data_unavailable_response(text: str) -> str | None:
    normalized = text.casefold()
    if any(token in normalized for token in ("मौसम", "weather", "तापमान", "temperature")):
        return "मेरे पास लाइव मौसम की जानकारी नहीं है, इसलिए मैं अंदाज़ा नहीं लगाना चाहता।"
    return None


def _response_tokens(text: str) -> set[str]:
    return {
        token.strip(".,!?;:()[]{}।?؟")
        for token in text.casefold().split()
        if len(token.strip(".,!?;:()[]{}।?؟")) > 1
    }


class _UnavailableSTTProvider(STTProvider):
    def __init__(self, *, provider_name: str, error: Exception) -> None:
        self.provider_name = provider_name
        self.error = error

    async def stream(
        self,
        audio_frames: AsyncIterator[CanonicalAudioFrame],
        language: str,
    ) -> AsyncIterator[TranscriptEvent]:
        async for _frame in audio_frames:
            break
        raise RuntimeError(f"{self.provider_name} STT unavailable: {self.error}")
        yield  # pragma: no cover


class _UnavailableLLMProvider(LLMProvider):
    def __init__(self, *, provider_name: str, error: Exception) -> None:
        self.provider_name = provider_name
        self.error = error

    async def stream(
        self,
        messages: list[LLMMessage],
        language: str,
        *,
        max_output_chars: int,
    ) -> AsyncIterator[LLMToken]:
        raise RuntimeError(f"{self.provider_name} LLM unavailable: {self.error}")
        yield  # pragma: no cover


class _UnavailableTTSProvider(TTSProvider):
    def __init__(self, *, provider_name: str, error: Exception) -> None:
        self.provider_name = provider_name
        self.error = error

    async def synthesize(self, text: str, language: str) -> AsyncIterator[TTSAudioFrame]:
        raise RuntimeError(f"{self.provider_name} TTS unavailable: {self.error}")
        yield  # pragma: no cover


async def _wait_until_started(task: asyncio.Task[None], started: asyncio.Event) -> None:
    started_task = asyncio.create_task(started.wait())
    done, pending = await asyncio.wait(
        {task, started_task},
        return_when=asyncio.FIRST_COMPLETED,
    )
    for pending_task in pending:
        if pending_task is started_task:
            pending_task.cancel()
    if task.done():
        task.result()
    if started_task in done:
        return


def _placeholder_pcm_frames(*, duration_ms: int) -> list[rtc.AudioFrame]:
    sample_rate = 16000
    samples_per_frame = 320
    total_samples = max(int(sample_rate * duration_ms / 1000), samples_per_frame)
    frames: list[rtc.AudioFrame] = []
    sample_index = 0
    while sample_index < total_samples:
        data = bytearray()
        for _ in range(samples_per_frame):
            value = int(900 * math.sin(2 * math.pi * 440 * sample_index / sample_rate))
            data.extend(struct.pack("<h", value))
            sample_index += 1
        frames.append(
            rtc.AudioFrame(
                data=data,
                sample_rate=sample_rate,
                num_channels=1,
                samples_per_channel=samples_per_frame,
            )
        )
    return frames


def _canonical_frame_from_livekit(frame: rtc.AudioFrame) -> CanonicalAudioFrame | None:
    sample_rate = int(getattr(frame, "sample_rate", 0) or 0)
    num_channels = int(getattr(frame, "num_channels", 0) or 0)
    samples_per_channel = int(getattr(frame, "samples_per_channel", 0) or 0)
    data = bytes(getattr(frame, "data", b""))
    if sample_rate <= 0 or num_channels <= 0 or samples_per_channel <= 0:
        return None
    duration_ms = max(round(samples_per_channel / sample_rate * 1000), 1)
    return CanonicalAudioFrame(
        pcm16=data,
        sample_rate=sample_rate,
        num_channels=num_channels,
        duration_ms=duration_ms,
    )


def _wall_clock_ms() -> int:
    import time

    return int(time.time() * 1000)


def _monotonic_ms() -> int:
    import time

    return round(time.perf_counter() * 1000)
