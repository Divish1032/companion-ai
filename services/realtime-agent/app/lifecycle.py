from __future__ import annotations

import asyncio
import math
import struct
from dataclasses import dataclass
from typing import Protocol

from livekit import api, rtc

from app.audio_pipeline import (
    CanonicalAudioFrame,
    EndpointEvent,
    EndpointingStateMachine,
    create_vad_provider,
)
from app.config import Settings
from app.events import EventSequencer, TurnIdFactory
from app.providers.mock import MockLLMProvider, MockSTTProvider, MockTTSProvider
from app.safety import SafetyClassifier


class AgentAssignmentError(Exception):
    pass


@dataclass(frozen=True)
class AgentAssignment:
    session_id: str
    room_name: str
    expires_at_ms: int
    recent_context: list[dict[str, object]]


class AgentTransport(Protocol):
    async def connect(self) -> None: ...
    async def publish_reliable(self, payload: bytes, topic: str = "critical") -> None: ...
    async def publish_placeholder_audio(self, duration_ms: int) -> None: ...
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
        self._audio_track_published = False
        self._seen_user_audio = False
        self._audio_tasks: set[asyncio.Task[None]] = set()

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
            if b"client_session_started" in payload or b"client_cancel_turn" in payload:
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

    async def publish_placeholder_audio(self, duration_ms: int) -> None:
        if not self.settings.enable_fake_audio:
            return
        if self.room is None:
            raise AgentAssignmentError("LiveKit room is not connected.")

        if self._audio_source is None:
            self._audio_source = rtc.AudioSource(sample_rate=16000, num_channels=1)
        if not self._audio_track_published:
            track = rtc.LocalAudioTrack.create_audio_track("fake-ai-audio", self._audio_source)
            await self.room.local_participant.publish_track(track)
            self._audio_track_published = True

        for frame in _placeholder_pcm_frames(duration_ms=duration_ms):
            await self._audio_source.capture_frame(frame)

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
        self.audio_publications = 0
        self.connected = False
        self.disconnected = False
        self.activity: asyncio.Queue[str | CanonicalAudioFrame] = asyncio.Queue()
        self.audio_publish_delay_seconds = audio_publish_delay_seconds

    async def connect(self) -> None:
        self.connected = True

    async def publish_reliable(self, payload: bytes, topic: str = "critical") -> None:
        self.events.append(payload)

    async def publish_placeholder_audio(self, duration_ms: int) -> None:
        self.audio_publications += 1
        if self.audio_publish_delay_seconds > 0:
            await asyncio.sleep(self.audio_publish_delay_seconds)

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
        stt_provider: MockSTTProvider | None = None,
        llm_provider: MockLLMProvider | None = None,
        tts_provider: MockTTSProvider | None = None,
        safety_classifier: SafetyClassifier | None = None,
    ) -> None:
        self.assignment = assignment
        self.settings = settings
        self.transport = transport
        self.stt_provider = stt_provider or MockSTTProvider()
        self.llm_provider = llm_provider or MockLLMProvider()
        self.tts_provider = tts_provider or MockTTSProvider()
        self.safety_classifier = safety_classifier or SafetyClassifier()
        self.sequencer = EventSequencer(assignment.session_id)
        self.turn_ids = TurnIdFactory(assignment.session_id)
        self._stt_forwarded_audio_ms = 0
        self.endpointing = EndpointingStateMachine(
            config=settings.vad_config(),
            vad_provider=create_vad_provider(settings.vad_config()),
            turn_id_factory=self.turn_ids.next,
            stt_audio_sink=self._record_stt_audio,
        )
        self._current_turn: asyncio.Task[None] | None = None
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
            await self.transport.disconnect()

    def cancel_current_turn(self) -> bool:
        if self._current_turn is None or self._current_turn.done():
            return False
        self._current_turn.cancel()
        return True

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
            if "client_cancel_turn" in activity:
                self.cancel_current_turn()
                await self._emit_state("listening", turn_id=None)
                continue
            if self._current_turn is None or self._current_turn.done():
                self._current_turn = asyncio.create_task(self._run_fake_turn())
            _ = now_ms

    async def _run_fake_turn(self) -> None:
        turn_id = self.turn_ids.next()
        await self._emit_state("thinking", turn_id=turn_id)

        prompt = " ".join(
            str(item.get("text", "")) for item in self.assignment.recent_context[-2:]
        ).strip()
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
        for event in self.endpointing.process_frame(frame):
            await self._handle_endpoint_event(event)

    async def _handle_endpoint_event(self, event: EndpointEvent) -> None:
        if event.type == "speech_start":
            if self._assistant_speaking or (
                self._current_turn is not None and not self._current_turn.done()
            ):
                cancelled = self.cancel_current_turn()
                await self._emit_barge_in(event, cancelled=cancelled)
            await self._emit_endpoint_event(event)
            await self._emit_state("user_speaking", turn_id=event.turn_id)
            return

        await self._emit_endpoint_event(event)
        if event.type == "speech_end":
            await self._emit_state("listening", turn_id=event.turn_id)

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

    async def _emit_barge_in(self, event: EndpointEvent, *, cancelled: bool) -> None:
        payload = {
            "stage": "during_speaking" if self._assistant_speaking else "before_tts",
            "cancelled": cancelled,
            "elapsed_ms": event.elapsed_ms,
        }
        await self.transport.publish_reliable(
            self.sequencer.encode(event_type="barge_in", turn_id=event.turn_id, payload=payload)
        )

    def _record_stt_audio(self, frame: CanonicalAudioFrame) -> None:
        self._stt_forwarded_audio_ms += frame.duration_ms


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
