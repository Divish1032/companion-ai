from app.audio_pipeline import (
    EndpointingStateMachine,
    EnergyVadProvider,
    VadConfig,
    pcm_silence_frame,
    pcm_sine_frame,
)


def test_clean_hinglish_sample_produces_speech_boundaries() -> None:
    forwarded_ms = 0
    machine = _machine(stt_audio_sink=lambda frame: _add_forwarded(frame.duration_ms))

    def _add_forwarded(duration_ms: int) -> None:
        nonlocal forwarded_ms
        forwarded_ms += duration_ms

    events = _run_sample(
        machine,
        [
            *_silence(150),
            *_speech(600),
            *_silence(630),
        ],
    )

    assert _event_types(events) == ["speech_start", "speech_end", "endpoint_commit"]
    assert events[0].pre_speech_ms >= 150
    assert forwarded_ms >= events[-1].forwarded_audio_ms
    assert events[-1].reason == "silence"


def test_long_pause_with_continuation_particle_waits_for_extended_silence() -> None:
    machine = _machine()

    events = _run_sample(
        machine,
        [
            *_speech(420),
            *_silence(630),
        ],
        partial_transcript="haan matlab",
    )

    assert _event_types(events) == ["speech_start"]

    events.extend(_run_sample(machine, _silence(480), partial_transcript="haan matlab"))

    assert _event_types(events) == ["speech_start", "speech_end", "endpoint_commit"]
    assert events[-1].elapsed_ms >= 1500


def test_cough_noise_sample_does_not_commit_turn() -> None:
    machine = _machine()

    events = _run_sample(
        machine,
        [
            pcm_sine_frame(duration_ms=90, amplitude=1500, frequency_hz=80),
            *_silence(900),
        ],
    )

    assert events == []


def test_trailing_particle_delays_endpoint_commit() -> None:
    machine = _machine()

    events = _run_sample(
        machine,
        [
            *_speech(360),
            *_silence(900),
        ],
        partial_transcript="aur",
    )

    assert _event_types(events) == ["speech_start"]


def test_forced_endpoint_prevents_runaway_utterance() -> None:
    machine = _machine(config=VadConfig(provider="energy", forced_endpoint_ms=300))

    events = _run_sample(machine, _speech(420))

    assert _event_types(events) == ["speech_start", "speech_end", "endpoint_commit"]
    assert events[-1].reason == "forced_endpoint"


def _machine(
    *,
    config: VadConfig | None = None,
    stt_audio_sink=None,  # noqa: ANN001
) -> EndpointingStateMachine:
    counter = 0

    def next_turn_id() -> str:
        nonlocal counter
        counter += 1
        return f"test:turn:{counter:04d}"

    return EndpointingStateMachine(
        config=config or VadConfig(provider="energy"),
        vad_provider=EnergyVadProvider(),
        turn_id_factory=next_turn_id,
        stt_audio_sink=stt_audio_sink,
    )


def _run_sample(
    machine: EndpointingStateMachine,
    frames,
    *,  # noqa: ANN001
    partial_transcript: str | None = None,
):
    events = []
    for frame in frames:
        events.extend(machine.process_frame(frame, partial_transcript=partial_transcript))
    return events


def _speech(duration_ms: int):
    return [
        pcm_sine_frame(duration_ms=30, amplitude=5000)
        for _ in range(max(duration_ms // 30, 1))
    ]


def _silence(duration_ms: int):
    return [pcm_silence_frame(duration_ms=30) for _ in range(max(duration_ms // 30, 1))]


def _event_types(events) -> list[str]:  # noqa: ANN001
    return [event.type for event in events]
