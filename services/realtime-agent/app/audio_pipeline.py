from __future__ import annotations

import math
import struct
from collections import deque
from collections.abc import Callable
from dataclasses import dataclass
from enum import Enum
from typing import Protocol


@dataclass(frozen=True)
class CanonicalAudioFrame:
    pcm16: bytes
    sample_rate: int
    num_channels: int
    duration_ms: int


@dataclass(frozen=True)
class VadConfig:
    provider: str = "silero"
    start_threshold: float = 0.55
    end_threshold: float = 0.35
    barge_in_threshold: float = 0.65
    min_confirmed_speech_ms: int = 200
    pre_speech_buffer_ms: int = 240
    endpoint_silence_ms: int = 600
    continuation_silence_ms: int = 1100
    coalescing_silence_ms: int = 1500
    forced_endpoint_ms: int = 9000


class VadProvider(Protocol):
    def speech_probability(self, frame: CanonicalAudioFrame) -> float: ...


class EnergyVadProvider:
    """Local deterministic fallback used for tests and dev when Silero is unavailable."""

    def __init__(self, *, speech_rms: int = 700, noise_rms: int = 120) -> None:
        self.speech_rms = speech_rms
        self.noise_rms = noise_rms

    def speech_probability(self, frame: CanonicalAudioFrame) -> float:
        if not frame.pcm16:
            return 0.0
        rms = _pcm16_rms(frame.pcm16)
        if rms <= self.noise_rms:
            return 0.0
        if rms >= self.speech_rms:
            return 1.0
        return (rms - self.noise_rms) / (self.speech_rms - self.noise_rms)


class SileroVadProvider:
    def __init__(self) -> None:
        try:
            import numpy as np
            from silero_vad import load_silero_vad
        except Exception as error:  # pragma: no cover - depends on optional runtime package
            raise RuntimeError("Silero VAD package is not installed.") from error

        self._np = np
        self._model = load_silero_vad()

    def speech_probability(self, frame: CanonicalAudioFrame) -> float:
        samples = self._np.frombuffer(frame.pcm16, dtype=self._np.int16).astype(self._np.float32)
        if samples.size == 0:
            return 0.0
        samples = samples / 32768.0
        result = self._model(samples, frame.sample_rate)
        if hasattr(result, "item"):
            return float(result.item())
        return float(result)


def create_vad_provider(config: VadConfig) -> VadProvider:
    if config.provider == "energy":
        return EnergyVadProvider()
    try:
        return SileroVadProvider()
    except RuntimeError:
        return EnergyVadProvider()


class EndpointState(str, Enum):
    IDLE = "idle"
    SPEECH_CANDIDATE = "speech_candidate"
    IN_SPEECH = "in_speech"
    ENDPOINT_CANDIDATE = "endpoint_candidate"


@dataclass(frozen=True)
class EndpointEvent:
    type: str
    turn_id: str
    elapsed_ms: int
    reason: str | None = None
    pre_speech_ms: int = 0
    forwarded_audio_ms: int = 0


class EndpointingStateMachine:
    def __init__(
        self,
        *,
        config: VadConfig,
        vad_provider: VadProvider,
        turn_id_factory: Callable[[], str],
        stt_audio_sink: Callable[[CanonicalAudioFrame], None] | None = None,
    ) -> None:
        self.config = config
        self.vad_provider = vad_provider
        self.turn_id_factory = turn_id_factory
        self.stt_audio_sink = stt_audio_sink
        self.state = EndpointState.IDLE
        self.current_turn_id: str | None = None
        self.elapsed_ms = 0
        self._candidate_ms = 0
        self._speech_ms = 0
        self._silence_ms = 0
        self._turn_audio_ms = 0
        self._forwarded_audio_ms = 0
        self._pre_speech: deque[CanonicalAudioFrame] = deque()

    def process_frame(
        self,
        frame: CanonicalAudioFrame,
        *,
        partial_transcript: str | None = None,
        force_endpoint: bool = False,
    ) -> list[EndpointEvent]:
        self.elapsed_ms += frame.duration_ms
        probability = self.vad_provider.speech_probability(frame)
        is_start_speech = probability >= self.config.start_threshold
        is_continued_speech = probability >= self.config.end_threshold
        events: list[EndpointEvent] = []
        self._remember_pre_speech(frame)

        if self.state == EndpointState.IDLE:
            if is_start_speech:
                self.current_turn_id = self.turn_id_factory()
                self.state = EndpointState.SPEECH_CANDIDATE
                self._candidate_ms = frame.duration_ms
            return events

        if self.state == EndpointState.SPEECH_CANDIDATE:
            if is_start_speech:
                self._candidate_ms += frame.duration_ms
                if self._candidate_ms >= self.config.min_confirmed_speech_ms:
                    self.state = EndpointState.IN_SPEECH
                    self._speech_ms = self._candidate_ms
                    self._silence_ms = 0
                    pre_speech_ms = self._flush_pre_speech()
                    assert self.current_turn_id is not None
                    events.append(
                        EndpointEvent(
                            type="speech_start",
                            turn_id=self.current_turn_id,
                            elapsed_ms=self.elapsed_ms,
                            pre_speech_ms=pre_speech_ms,
                            forwarded_audio_ms=self._forwarded_audio_ms,
                        )
                    )
            else:
                self._reset_turn()
            return events

        if self.state in {EndpointState.IN_SPEECH, EndpointState.ENDPOINT_CANDIDATE}:
            self._turn_audio_ms += frame.duration_ms
            if is_continued_speech:
                self._speech_ms += frame.duration_ms
                self._silence_ms = 0
                self.state = EndpointState.IN_SPEECH
                self._forward(frame)
            else:
                self._silence_ms += frame.duration_ms
                self._forward(frame)
                if self.state == EndpointState.IN_SPEECH and (
                    self._silence_ms >= self.config.endpoint_silence_ms
                ):
                    self.state = EndpointState.ENDPOINT_CANDIDATE

            if force_endpoint or self._speech_ms >= self.config.forced_endpoint_ms:
                events.extend(self._commit(reason="forced_endpoint"))
            elif self.state == EndpointState.ENDPOINT_CANDIDATE:
                required_silence = (
                    max(
                        self.config.continuation_silence_ms,
                        self.config.coalescing_silence_ms,
                    )
                    if _suggests_continuation(partial_transcript)
                    else self.config.coalescing_silence_ms
                )
                if self._silence_ms >= required_silence:
                    events.extend(self._commit(reason="silence"))
            return events

        return events

    def _remember_pre_speech(self, frame: CanonicalAudioFrame) -> None:
        self._pre_speech.append(frame)
        total_ms = sum(item.duration_ms for item in self._pre_speech)
        while total_ms > self.config.pre_speech_buffer_ms and self._pre_speech:
            removed = self._pre_speech.popleft()
            total_ms -= removed.duration_ms

    def _flush_pre_speech(self) -> int:
        total_ms = 0
        while self._pre_speech:
            frame = self._pre_speech.popleft()
            self._forward(frame)
            total_ms += frame.duration_ms
        return total_ms

    def _forward(self, frame: CanonicalAudioFrame) -> None:
        self._forwarded_audio_ms += frame.duration_ms
        if self.stt_audio_sink is not None:
            self.stt_audio_sink(frame)

    def _commit(self, *, reason: str) -> list[EndpointEvent]:
        assert self.current_turn_id is not None
        events = [
            EndpointEvent(
                type="speech_end",
                turn_id=self.current_turn_id,
                elapsed_ms=self.elapsed_ms,
                reason=reason,
                forwarded_audio_ms=self._forwarded_audio_ms,
            ),
            EndpointEvent(
                type="endpoint_commit",
                turn_id=self.current_turn_id,
                elapsed_ms=self.elapsed_ms,
                reason=reason,
                forwarded_audio_ms=self._forwarded_audio_ms,
            ),
        ]
        self._reset_turn()
        return events

    def _reset_turn(self) -> None:
        self.state = EndpointState.IDLE
        self.current_turn_id = None
        self._candidate_ms = 0
        self._speech_ms = 0
        self._silence_ms = 0
        self._turn_audio_ms = 0
        self._forwarded_audio_ms = 0


def pcm_sine_frame(
    *,
    duration_ms: int,
    amplitude: int = 5000,
    sample_rate: int = 16000,
    frequency_hz: int = 220,
) -> CanonicalAudioFrame:
    samples = int(sample_rate * duration_ms / 1000)
    data = bytearray()
    for sample_index in range(samples):
        value = int(amplitude * math.sin(2 * math.pi * frequency_hz * sample_index / sample_rate))
        data.extend(value.to_bytes(2, byteorder="little", signed=True))
    return CanonicalAudioFrame(
        pcm16=bytes(data),
        sample_rate=sample_rate,
        num_channels=1,
        duration_ms=duration_ms,
    )


def pcm_silence_frame(*, duration_ms: int, sample_rate: int = 16000) -> CanonicalAudioFrame:
    samples = int(sample_rate * duration_ms / 1000)
    return CanonicalAudioFrame(
        pcm16=b"\x00\x00" * samples,
        sample_rate=sample_rate,
        num_channels=1,
        duration_ms=duration_ms,
    )


def to_mono_pcm16(
    frame: CanonicalAudioFrame,
    *,
    target_sample_rate: int,
) -> bytes:
    if frame.sample_rate <= 0 or frame.num_channels <= 0:
        raise ValueError("Audio frame must include a positive sample rate and channel count.")

    mono = _downmix_pcm16_to_mono(frame.pcm16, frame.num_channels)
    if frame.sample_rate == target_sample_rate:
        return mono
    return _resample_pcm16_linear(
        mono,
        source_sample_rate=frame.sample_rate,
        target_sample_rate=target_sample_rate,
    )


def _suggests_continuation(partial_transcript: str | None) -> bool:
    if not partial_transcript:
        return False
    cleaned = partial_transcript.strip().lower().rstrip(".,!?। ")
    if cleaned.endswith("..."):
        return True
    trailing_particles = ("toh", "aur", "phir", "matlab", "haan", "han")
    return any(cleaned.endswith(particle) for particle in trailing_particles)


def _pcm16_rms(data: bytes) -> int:
    sample_count = len(data) // 2
    if sample_count == 0:
        return 0
    samples = struct.unpack(f"<{sample_count}h", data[: sample_count * 2])
    mean_square = sum(sample * sample for sample in samples) / sample_count
    return int(math.sqrt(mean_square))


def _downmix_pcm16_to_mono(pcm16: bytes, num_channels: int) -> bytes:
    sample_count = len(pcm16) // 2
    if sample_count == 0:
        return b""
    samples = struct.unpack(f"<{sample_count}h", pcm16[: sample_count * 2])
    if num_channels == 1:
        return struct.pack(f"<{len(samples)}h", *samples)

    frame_count = len(samples) // num_channels
    mono_samples = []
    for frame_index in range(frame_count):
        start = frame_index * num_channels
        mono_samples.append(round(sum(samples[start : start + num_channels]) / num_channels))
    return struct.pack(f"<{len(mono_samples)}h", *mono_samples)


def _resample_pcm16_linear(
    pcm16: bytes,
    *,
    source_sample_rate: int,
    target_sample_rate: int,
) -> bytes:
    source_count = len(pcm16) // 2
    if source_count == 0:
        return b""
    source = struct.unpack(f"<{source_count}h", pcm16[: source_count * 2])
    target_count = max(round(source_count * target_sample_rate / source_sample_rate), 1)
    if target_count == 1:
        return struct.pack("<h", source[0])

    ratio = (source_count - 1) / (target_count - 1)
    resampled = []
    for target_index in range(target_count):
        position = target_index * ratio
        left = int(position)
        right = min(left + 1, source_count - 1)
        fraction = position - left
        value = round(source[left] + (source[right] - source[left]) * fraction)
        resampled.append(value)
    return struct.pack(f"<{len(resampled)}h", *resampled)
