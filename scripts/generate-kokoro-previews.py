#!/usr/bin/env python3
"""Generate the fixed, non-user Kokoro Hindi preview assets used by the app."""

from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREVIEW_DIR = ROOT / "services/api/app/static/tts-previews"
KOKORO_URL = "http://127.0.0.1:8880/v1/audio/speech"
MODEL_IMAGE = (
    "ghcr.io/remsky/kokoro-fastapi-cpu:v0.6.0@"
    "sha256:d2c63627e80e32df7fab7f1e969c2b6b26272439d837ef195f40d4a82eca195e"
)
PREVIEW_TEXT = "नमस्ते, आज आपका दिन कैसा रहा?"
VOICES = {
    "hi_aarohi": "hf_alpha",
    "hi_naina": "hf_beta",
    "hi_kabir": "hm_omega",
    "hi_vihaan": "hm_psi",
}


def synthesize(voice: str) -> bytes:
    request = urllib.request.Request(
        KOKORO_URL,
        data=json.dumps(
            {
                "model": "kokoro",
                "input": PREVIEW_TEXT,
                "voice": voice,
                "response_format": "pcm",
                "stream": True,
                "lang_code": "h",
                "speed": 1.0,
                "return_download_link": False,
            }
        ).encode(),
        headers={"content-type": "application/json", "accept": "audio/pcm"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        pcm = response.read()
    if len(pcm) < 960 or len(pcm) % 2:
        raise RuntimeError(f"Kokoro returned invalid PCM for {voice} ({len(pcm)} bytes).")
    return pcm


def encode_opus(pcm: bytes, destination: Path) -> None:
    with tempfile.NamedTemporaryFile(suffix=".pcm") as source:
        source.write(pcm)
        source.flush()
        subprocess.run(
            [
                "ffmpeg",
                "-loglevel",
                "error",
                "-y",
                "-f",
                "s16le",
                "-ar",
                "24000",
                "-ac",
                "1",
                "-i",
                source.name,
                "-c:a",
                "libopus",
                "-b:a",
                "32k",
                str(destination),
            ],
            check=True,
        )


def main() -> None:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {
        "model_image": MODEL_IMAGE,
        "preview_text": PREVIEW_TEXT,
        "sample_rate": 24000,
        "codec": "opus",
        "voices": {},
    }
    for public_id, pack in VOICES.items():
        destination = PREVIEW_DIR / f"{public_id}.opus"
        encode_opus(synthesize(pack), destination)
        manifest["voices"][public_id] = {
            "kokoro_voice": pack,
            "file": destination.name,
            "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
        }
    (PREVIEW_DIR / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"Generated {len(VOICES)} fixed Kokoro Hindi previews in {PREVIEW_DIR}.")


if __name__ == "__main__":
    main()
