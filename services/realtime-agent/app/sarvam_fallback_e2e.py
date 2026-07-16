"""Paid, manual Sarvam fallback check; never prints the request text or key."""

from __future__ import annotations

import asyncio

from app.config import Settings
from app.lifecycle import create_tts_provider


async def main() -> None:
    settings = Settings(kokoro_base_url="http://127.0.0.1:1")
    if not settings.sarvam_api_key:
        raise SystemExit("AGENT_SARVAM_API_KEY is required for the paid fallback check.")

    provider = create_tts_provider(settings, language="hi-IN", voice_id="hi_aarohi")
    try:
        frames = [frame async for frame in provider.synthesize("नमस्ते, जांच पूरी हुई।", "hi-IN")]
    finally:
        await provider.close()

    if not frames or any(frame.provider != "sarvam" for frame in frames):
        raise SystemExit("Sarvam fallback check did not produce only Sarvam audio frames.")
    print(f"Sarvam fallback E2E passed with {len(frames)} PCM frames.")


if __name__ == "__main__":
    asyncio.run(main())
