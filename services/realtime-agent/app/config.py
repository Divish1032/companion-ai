import tomllib
from pathlib import Path
from typing import Any

from pydantic_settings import BaseSettings, SettingsConfigDict

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

    model_config = SettingsConfigDict(env_file=".env", env_prefix="AGENT_")


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
