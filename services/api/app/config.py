from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    service_name: str = "companion-api"
    environment: str = "local"
    redis_url: str = "redis://redis:6379/0"
    livekit_url: str = "ws://livekit:7880"
    livekit_api_key: str = ""
    livekit_api_secret: str = ""
    agent_assignment_url: str = "http://realtime-agent:8001/v1/agent/assign"
    agent_assignment_timeout_seconds: float = 5.0
    durable_store_path: str = "/tmp/companion_api_sessions.sqlite"
    livekit_token_ttl_seconds: int = 600
    max_session_seconds: int = 1200
    max_recent_context_messages: int = 12
    session_create_limit_per_day: int = 50
    token_mint_limit_per_session: int = 20

    model_config = SettingsConfigDict(env_file=".env", env_prefix="API_")
