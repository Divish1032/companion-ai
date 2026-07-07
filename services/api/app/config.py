from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    service_name: str = "companion-api"
    environment: str = "local"
    redis_url: str = "redis://redis:6379/0"
    livekit_url: str = "ws://livekit:7880"
    livekit_api_key: str = ""
    livekit_api_secret: str = ""

    model_config = SettingsConfigDict(env_file=".env", env_prefix="API_")
