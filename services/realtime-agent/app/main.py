from fastapi import FastAPI

from app.config import load_provider_routing

app = FastAPI(title="Companion AI Realtime Agent", version="0.1.0")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "companion-realtime-agent"}


@app.get("/debug/provider-route/{language}")
async def provider_route(language: str) -> dict[str, str]:
    route = load_provider_routing().for_language(language)

    return {
        "language": language,
        "stt": route.stt,
        "llm": route.llm,
        "tts": route.tts,
    }
