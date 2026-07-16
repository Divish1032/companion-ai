import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.audio_pipeline import VadConfig
from app.providers import ProviderRouting


class Settings(BaseSettings):
    service_name: str = "companion-realtime-agent"
    environment: str = "local"
    redis_url: str = "redis://redis:6379/1"
    livekit_url: str = "ws://livekit:7880"
    livekit_api_key: str = ""
    livekit_api_secret: str = ""
    persona_config: str = "config/personas/hindi_companion_v1.toml"
    max_concurrent_agents: int = 10
    max_agent_memory_mb: int = 512
    max_idle_seconds: int = 120
    memory_api_base_url: str = "http://api:8000"
    enable_memory_planner: bool = False
    memory_planner_model: str = "Qwen/Qwen3-0.6B"
    memory_planner_timeout_seconds: float = 0.1
    # Phone-owned vector lookup includes a reliable data-channel round trip and
    # a warm local embedding.  200 ms caused systematic false fallbacks on real
    # devices; retain a bounded one-second budget instead.
    memory_lookup_timeout_seconds: float = 1.0
    enable_metrics_ingest: bool = False
    metrics_ingest_url: str = "http://api:8000/v1/telemetry/ingest"
    metrics_ingest_token: str = ""
    enable_livekit_rtc: bool = True
    enable_fake_audio: bool = True
    fake_audio_ms: int = 550
    language: str = "hi-IN"
    stt_provider: str = ""
    stt_model: str = "vosk-model-small-hi-0.22"
    vosk_model_path: str = ""
    stt_min_confidence: float = 0.35
    sarvam_stt_model: str = "saaras:v3"
    sarvam_stt_mode: str = "codemix"
    sarvam_stt_chunk_ms: int = 120
    sarvam_stt_response_timeout_seconds: float = 5.0
    sarvam_stt_price_per_hour: float = 30.0
    llm_provider: str = ""
    llm_model: str = "sarvam-30b"
    tts_provider: str = ""
    tts_fallback_provider: str = ""
    tts_model: str = "bulbul:v3"
    tts_speaker: str = "shubh"
    tts_sample_rate: int = 24000
    tts_timeout_seconds: float = 12.0
    tts_price_per_10k_chars: float = 30.0
    kokoro_base_url: str = "http://kokoro-tts:8880/v1"
    kokoro_model: str = "kokoro"
    kokoro_first_audio_timeout_seconds: float = 2.0
    kokoro_total_timeout_seconds: float = 12.0
    kokoro_readiness_timeout_seconds: float = 30.0
    voice_catalog: str = "config/voices/hindi_v1.toml"
    sarvam_api_key: str = Field(
        default="",
        validation_alias=AliasChoices("AGENT_SARVAM_API_KEY", "SARVAM_API_KEY"),
    )
    sarvam_base_url: str = "https://api.sarvam.ai/v1"
    sarvam_tts_base_url: str = "https://api.sarvam.ai"
    llm_timeout_seconds: float = 12.0
    vad_provider: str = "silero"
    vad_start_threshold: float = 0.55
    vad_end_threshold: float = 0.35
    vad_barge_in_threshold: float = 0.65
    vad_min_confirmed_speech_ms: int = 200
    vad_pre_speech_buffer_ms: int = 240
    vad_endpoint_silence_ms: int = 600
    vad_continuation_silence_ms: int = 1100
    vad_coalescing_silence_ms: int = 1500
    vad_forced_endpoint_ms: int = 9000

    model_config = SettingsConfigDict(env_file=".env", env_prefix="AGENT_")

    def vad_config(self) -> VadConfig:
        return VadConfig(
            provider=self.vad_provider,
            start_threshold=self.vad_start_threshold,
            end_threshold=self.vad_end_threshold,
            barge_in_threshold=self.vad_barge_in_threshold,
            min_confirmed_speech_ms=self.vad_min_confirmed_speech_ms,
            pre_speech_buffer_ms=self.vad_pre_speech_buffer_ms,
            endpoint_silence_ms=self.vad_endpoint_silence_ms,
            continuation_silence_ms=self.vad_continuation_silence_ms,
            coalescing_silence_ms=self.vad_coalescing_silence_ms,
            forced_endpoint_ms=self.vad_forced_endpoint_ms,
        )


@dataclass(frozen=True)
class PersonaSettings:
    system_prompt: str
    max_output_chars: int
    partial_chunk_chars: int
    history_messages: int


def _repo_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        if (parent / "config" / "personas").is_dir():
            return parent
    return Path.cwd()


def load_toml(path: str | Path) -> dict[str, Any]:
    with Path(path).open("rb") as file:
        return tomllib.load(file)


def load_provider_routing() -> ProviderRouting:
    settings = Settings()
    path = Path(settings.persona_config)
    if not path.is_absolute():
        path = _repo_root() / path

    return ProviderRouting.from_dict(load_toml(path))


def load_persona_settings(settings: Settings) -> PersonaSettings:
    data = _load_persona_config(settings)
    prompt = data.get("prompt", {})
    response = data.get("response", {})
    history = data.get("history", {})
    return PersonaSettings(
        system_prompt=str(prompt.get("system", "")).strip(),
        max_output_chars=int(response.get("max_chars", 240)),
        partial_chunk_chars=int(response.get("partial_chunk_chars", 48)),
        history_messages=int(history.get("messages", 4)),
    )


def _load_persona_config(settings: Settings) -> dict[str, Any]:
    path = Path(settings.persona_config)
    if not path.is_absolute():
        path = _repo_root() / path
    return load_toml(path)
