from fastapi import FastAPI

from app.config import Settings

settings = Settings()
app = FastAPI(title="Companion AI API", version="0.1.0")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": settings.service_name}


@app.get("/config")
async def config() -> dict[str, str]:
    return {
        "environment": settings.environment,
        "livekit_url": settings.livekit_url,
    }
