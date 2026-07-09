from __future__ import annotations

import asyncio
import json
import math
import struct
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Protocol

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
from app.providers import (
    LLMProvider,
    PersonaLLMProvider,
    ProviderRouting,
    SarvamBulbulTTSProvider,
    SarvamChatLLMProvider,
    SarvamSTTProvider,
    STTProvider,
    TTSProvider,
    VoskSTTProvider,
)
from app.providers.interfaces import LLMMessage, LLMToken, TTSAudioFrame, TranscriptEvent
from app.providers.mock import MockSTTProvider, MockTTSProvider
from app.safety import SafetyClassifier


MEMORY_LOOKUP_TIMEOUT_SECONDS = 0.2


class AgentAssignmentError(Exception):
    pass


@dataclass(frozen=True)
class AgentAssignment:
    session_id: str
    room_name: str
    expires_at_ms: int
    recent_context: dict[str, object] | list[dict[str, object]]


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
    ) -> None:
        self.assignment = assignment
        self.settings = settings
        self.transport = transport
        self.stt_provider = stt_provider or create_stt_provider(settings)
        self.llm_provider = llm_provider or create_llm_provider(settings)
        self.tts_provider = tts_provider or create_tts_provider(settings)
        self.safety_classifier = safety_classifier or SafetyClassifier()
        self.persona = load_persona_settings(settings)
        self.context_builder = PromptContextBuilder(
            system_prompt=self.persona.system_prompt,
            initial_context=assignment.recent_context,
            max_recent_messages=self.persona.history_messages,
        )
        self.sequencer = EventSequencer(assignment.session_id)
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
        self._pending_memory_requests: dict[tuple[str, int], asyncio.Future[list[dict[str, object]]]] = {}
        self._stopped = asyncio.Event()
        self.started = asyncio.Event()
        self._assistant_speaking = False

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
            await self.transport.disconnect()

    def cancel_current_turn(self) -> bool:
        if self._current_turn is None or self._current_turn.done():
            return False
        self._current_turn.cancel()
        self._assistant_speaking = False
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
                payload={"message": message, "source": "realtime_agent"},
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
        if event.type == "speech_start":
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
        status = "final"
        repeat_reason: str | None = None
        if not event.text:
            status = "empty"
            repeat_reason = "empty_transcript"
        elif event.confidence is not None and event.confidence < self.settings.stt_min_confidence:
            status = "low_confidence"
            repeat_reason = "low_confidence"

        await self.transport.publish_reliable(
            self.sequencer.encode(
                event_type="transcript_final",
                turn_id=turn_id,
                payload={
                    "text": event.text,
                    "status": status,
                    "language": self.settings.language,
                    "confidence": event.confidence,
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
            },
            flush=True,
        )
        if repeat_reason is not None:
            await self._emit_transcript_repeat(turn_id, reason=repeat_reason, metrics=metrics)
            return

        self.cancel_current_turn()
        self._current_turn = asyncio.create_task(
            self._respond_to_final_transcript(turn_id, event.text)
        )

    async def _respond_to_final_transcript(self, turn_id: str, user_text: str) -> None:
        await self._emit_state("thinking", turn_id=turn_id)
        decision = self.safety_classifier.classify_input(user_text)
        if decision.response_override is not None:
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
            return

        try:
            text, clipped, last_token = await self._stream_llm_response(turn_id, user_text)
        except Exception as error:
            text = self.persona.fallback_response
            clipped = False
            last_token = LLMToken(
                text="",
                provider=selected_llm_provider_name(self.settings),
                model=self.settings.llm_model,
            )
            print(
                "llm_error",
                {
                    "session_id": self.assignment.session_id,
                    "turn_id": turn_id,
                    "provider": last_token.provider,
                    "message": str(error),
                },
                flush=True,
            )

        output_decision = self.safety_classifier.classify_output(text)
        if output_decision.response_override is not None:
            text = output_decision.response_override
            clipped = False
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
    ) -> tuple[str, bool, LLMToken | None]:
        messages = await self._llm_messages(turn_id, user_text)
        chunks: list[str] = []
        last_token: LLMToken | None = None
        async for token in self.llm_provider.stream(
            messages,
            self.settings.language,
            max_output_chars=self.persona.max_output_chars,
        ):
            chunks.append(token.text)
            last_token = token
            partial = "".join(chunks).strip()
            if partial:
                await self._emit_assistant_partial(turn_id, partial, token)
        text = "".join(chunks).strip()
        clipped_text, clipped = _clip_response_text(text, max_chars=self.persona.max_output_chars)
        return clipped_text, clipped, last_token

    async def _llm_messages(self, turn_id: str, user_text: str) -> list[LLMMessage]:
        memory_route = route_memory_query(user_text)
        turn_memory_packets: list[dict[str, object]] = []
        if memory_route.route not in {"none", "safety"} and memory_route.max_blocks > 0:
            turn_memory_packets = await self._lookup_turn_memory(turn_id, user_text, memory_route)
        messages, diagnostics = self.context_builder.build(
            user_text,
            turn_memory_packets=turn_memory_packets,
        )
        print(
            "prompt_context",
            {
                "session_id": self.assignment.session_id,
                "memory_route": memory_route.route,
                "memory_route_confidence": memory_route.confidence,
                "memory_route_reason": memory_route.reason,
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
    ) -> list[dict[str, object]]:
        event = self.sequencer.next(
            event_type="memory_lookup_request",
            turn_id=turn_id,
            payload={
                "query_text": user_text,
                "route": memory_route.route,
                "route_confidence": memory_route.confidence,
                "route_reason": memory_route.reason,
                "max_blocks": memory_route.max_blocks,
            },
        )
        sequence = event["sequence"]
        if not isinstance(sequence, int):
            return []
        loop = asyncio.get_running_loop()
        future: asyncio.Future[list[dict[str, object]]] = loop.create_future()
        key = (turn_id, sequence)
        self._pending_memory_requests[key] = future
        await self.transport.publish_reliable(
            json.dumps(event, separators=(",", ":")).encode("utf-8")
        )
        try:
            return await asyncio.wait_for(future, MEMORY_LOOKUP_TIMEOUT_SECONDS)
        except TimeoutError:
            print(
                "memory_lookup_timeout",
                {
                    "session_id": self.assignment.session_id,
                    "turn_id": turn_id,
                    "request_sequence": sequence,
                    "memory_route": memory_route.route,
                    "timeout_ms": round(MEMORY_LOOKUP_TIMEOUT_SECONDS * 1000),
                },
                flush=True,
            )
            return []
        finally:
            self._pending_memory_requests.pop(key, None)

    async def _handle_client_data_event(self, activity: str) -> bool:
        try:
            event = json.loads(activity)
        except json.JSONDecodeError:
            return False
        if not isinstance(event, dict) or event.get("type") != "memory_lookup_response":
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
        packets = [
            packet
            for packet in raw_packets
            if isinstance(packet, dict)
        ][:6] if isinstance(raw_packets, list) else []
        future.set_result(packets)
        print(
            "memory_lookup_response",
            {
                "session_id": self.assignment.session_id,
                "turn_id": turn_id,
                "request_sequence": request_sequence,
                "elapsed_ms": event.get("elapsed_ms"),
                "memory_packets": len(packets),
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
        first_audio_ms: int | None = None
        totals = {
            "chars": 0,
            "audio_ms": 0,
            "billed_units": 0.0,
            "cost_units": 0.0,
        }
        provider = selected_tts_provider_name(self.settings)
        model = self.settings.tts_model
        try:
            async for tts_frame in self.tts_provider.synthesize(text, self.settings.language):
                if first_audio_ms is None:
                    first_audio_ms = _monotonic_ms() - started
                _add_tts_totals(totals, tts_frame)
                provider = tts_frame.provider or provider
                model = tts_frame.model or model
                await self.transport.publish_audio_frame(tts_frame.frame)
        except asyncio.CancelledError:
            await self.transport.stop_audio(fade_out_ms=60)
            raise
        except Exception as error:
            await self._emit_tts_error(turn_id, str(error))
            print(
                "tts_error",
                {
                    "session_id": self.assignment.session_id,
                    "turn_id": turn_id,
                    "provider": provider,
                    "message": str(error),
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
        print(
            "tts_final",
            {"session_id": self.assignment.session_id, "turn_id": turn_id, **metrics},
            flush=True,
        )

    async def _emit_tts_metrics(self, turn_id: str, metrics: dict[str, object]) -> None:
        await self.transport.publish_reliable(
            self.sequencer.encode(event_type="tts_metrics", turn_id=turn_id, payload=metrics)
        )

    async def _emit_tts_error(self, turn_id: str, message: str) -> None:
        await self.transport.publish_reliable(
            self.sequencer.encode(
                event_type="tts_error",
                turn_id=turn_id,
                payload={"message": message, "provider": selected_tts_provider_name(self.settings)},
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
                payload={"message": message, "provider": selected_stt_provider_name(self.settings)},
            )
        )
        print(
            "stt_error",
            {"session_id": self.assignment.session_id, "turn_id": turn_id, "message": message},
            flush=True,
        )
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
            return SarvamSTTProvider()
        raise AgentAssignmentError(f"Unsupported STT provider: {provider_name}")
    except Exception as error:
        return _UnavailableSTTProvider(provider_name=provider_name, error=error)


def create_llm_provider(settings: Settings) -> LLMProvider:
    provider_name = selected_llm_provider_name(settings)
    try:
        if provider_name in {"persona_local", "mock"}:
            return PersonaLLMProvider()
        if provider_name == "sarvam":
            return SarvamChatLLMProvider(
                api_key=settings.sarvam_api_key,
                model=settings.llm_model,
                base_url=settings.sarvam_base_url,
                timeout_seconds=settings.llm_timeout_seconds,
            )
        raise AgentAssignmentError(f"Unsupported LLM provider: {provider_name}")
    except Exception as error:
        return _UnavailableLLMProvider(provider_name=provider_name, error=error)


def create_tts_provider(settings: Settings) -> TTSProvider:
    provider_name = selected_tts_provider_name(settings)
    try:
        if provider_name == "mock":
            return MockTTSProvider()
        if provider_name == "sarvam":
            return SarvamBulbulTTSProvider(
                api_key=settings.sarvam_api_key,
                model=settings.tts_model,
                base_url=settings.sarvam_tts_base_url,
                speaker=settings.tts_speaker,
                sample_rate=settings.tts_sample_rate,
                timeout_seconds=settings.tts_timeout_seconds,
                price_per_10k_chars=settings.tts_price_per_10k_chars,
            )
        raise AgentAssignmentError(f"Unsupported TTS provider: {provider_name}")
    except Exception as error:
        return _UnavailableTTSProvider(provider_name=provider_name, error=error)


def selected_llm_provider_name(settings: Settings) -> str:
    if settings.llm_provider:
        return settings.llm_provider
    try:
        routing = ProviderRouting.from_dict(_load_persona_config(settings))
        return routing.for_language(settings.language).llm
    except Exception:
        return "persona_local"


def selected_stt_provider_name(settings: Settings) -> str:
    if settings.stt_provider:
        return settings.stt_provider
    try:
        routing = ProviderRouting.from_dict(_load_persona_config(settings))
        return routing.for_language(settings.language).stt
    except Exception:
        return "vosk"


def selected_tts_provider_name(settings: Settings) -> str:
    if settings.tts_provider:
        return settings.tts_provider
    try:
        routing = ProviderRouting.from_dict(_load_persona_config(settings))
        return routing.for_language(settings.language).tts
    except Exception:
        return "mock"


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


def _clip_response_text(text: str, *, max_chars: int) -> tuple[str, bool]:
    if len(text) <= max_chars:
        return text, False
    boundary = max(text.rfind(marker, 0, max_chars) for marker in (".", "?", "!", "।"))
    if boundary < max_chars // 2:
        boundary = text.rfind(" ", 0, max_chars)
    if boundary <= 0:
        boundary = max_chars
    return text[:boundary].strip(), True


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
