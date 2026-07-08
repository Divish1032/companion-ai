import tomllib
from pathlib import Path
from typing import Any

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
    enable_livekit_rtc: bool = True
    enable_fake_audio: bool = True
    fake_audio_ms: int = 550
    language: str = "hi-IN"
    stt_provider: str = ""
    stt_model: str = "vosk-model-small-hi-0.22"
    vosk_model_path: str = ""
    stt_min_confidence: float = 0.35
    vad_provider: str = "silero"
    vad_start_threshold: float = 0.55
    vad_end_threshold: float = 0.35
    vad_barge_in_threshold: float = 0.65
    vad_min_confirmed_speech_ms: int = 200
    vad_pre_speech_buffer_ms: int = 240
    vad_endpoint_silence_ms: int = 600
    vad_continuation_silence_ms: int = 1100
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
            forced_endpoint_ms=self.vad_forced_endpoint_ms,
        )


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
