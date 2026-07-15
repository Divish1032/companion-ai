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
    max_memory_context_blocks: int = 6
    session_create_limit_per_day: int = 50
    token_mint_limit_per_session: int = 20
    enable_memory_embeddings: bool = False
    memory_embedding_model: str = "google/embeddinggemma-300m"
    memory_embedding_revision: str = "57c266a740f537b4dc058e1b0cda161fd15afa75"
    memory_embedding_dimension: int = 768
    memory_embedding_backend: str = "onnx"
    memory_embedding_model_path: str = "/models/huggingface/embeddinggemma-onnx-fp32-r57c266a7"
    embedding_timeout_seconds: float = 1.0
    enable_memory_reranker: bool = False
    memory_reranker_model: str = "Qwen/Qwen3-Reranker-0.6B"
    reranker_timeout_seconds: float = 0.12
    enable_memory_planner: bool = False
    memory_planner_model: str = "Qwen/Qwen3-0.6B"
    planner_timeout_seconds: float = 0.1
    enable_memory_extraction: bool = False
    memory_extraction_base_url: str = ""
    memory_extraction_api_key: str = ""
    memory_extraction_model: str = ""
    memory_extraction_timeout_seconds: float = 20.0

    model_config = SettingsConfigDict(env_file=".env", env_prefix="API_")
