#!/usr/bin/env python3
"""Measure local Kokoro Hindi streaming latency without recording spoken text."""

from __future__ import annotations

import concurrent.futures
import json
import os
import statistics
import time
import urllib.error
import urllib.request

BASE_URL = os.environ.get("KOKORO_BASE_URL", "http://127.0.0.1:8880/v1").rstrip("/")
REQUESTS_PER_LEVEL = int(os.environ.get("KOKORO_BENCHMARK_REQUESTS", "10"))
CONCURRENCY_LEVELS = (1, 5)
WARMUP_REQUESTS = 1
VOICE = "hf_alpha"
# This stable Hindi phrase is intentionally not written to logs or output.
INPUT = "नमस्ते, आज आपका दिन कैसा रहा?"


def percentile(values: list[float], percentage: float) -> float:
    if not values:
        raise ValueError("Cannot calculate a percentile from no values.")
    ordered = sorted(values)
    index = (len(ordered) - 1) * percentage
    lower = int(index)
    upper = min(lower + 1, len(ordered) - 1)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (index - lower)


def synthesize_once() -> dict[str, float]:
    request = urllib.request.Request(
        f"{BASE_URL}/audio/speech",
        data=json.dumps(
            {
                "model": "kokoro",
                "input": INPUT,
                "voice": VOICE,
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
    started = time.perf_counter()
    first_audio_ms: float | None = None
    bytes_received = 0
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            while chunk := response.read(8192):
                if first_audio_ms is None:
                    first_audio_ms = (time.perf_counter() - started) * 1000
                bytes_received += len(chunk)
    except urllib.error.URLError as error:
        raise RuntimeError(f"Kokoro request failed: {error.reason}") from error

    total_ms = (time.perf_counter() - started) * 1000
    if first_audio_ms is None or bytes_received < 960 or bytes_received % 2:
        raise RuntimeError(f"Kokoro returned invalid PCM ({bytes_received} bytes).")
    audio_ms = bytes_received / 2 / 24_000 * 1000
    return {
        "first_audio_ms": first_audio_ms,
        "total_ms": total_ms,
        "audio_ms": audio_ms,
        "real_time_factor": total_ms / audio_ms,
    }


def benchmark_level(concurrency: int) -> dict[str, object]:
    started = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        samples = list(executor.map(lambda _: synthesize_once(), range(REQUESTS_PER_LEVEL)))
    elapsed_ms = (time.perf_counter() - started) * 1000
    return {
        "concurrency": concurrency,
        "samples": len(samples),
        "wall_ms": round(elapsed_ms, 1),
        "requests_per_second": round(len(samples) / (elapsed_ms / 1000), 3),
        "first_audio_ms": {
            "p50": round(statistics.median(item["first_audio_ms"] for item in samples), 1),
            "p95": round(percentile([item["first_audio_ms"] for item in samples], 0.95), 1),
        },
        "total_ms": {
            "p50": round(statistics.median(item["total_ms"] for item in samples), 1),
            "p95": round(percentile([item["total_ms"] for item in samples], 0.95), 1),
        },
        "real_time_factor": {
            "p50": round(statistics.median(item["real_time_factor"] for item in samples), 3),
            "p95": round(percentile([item["real_time_factor"] for item in samples], 0.95), 3),
        },
    }


def main() -> None:
    if REQUESTS_PER_LEVEL < max(CONCURRENCY_LEVELS):
        raise SystemExit(
            "KOKORO_BENCHMARK_REQUESTS must be at least 5 so the five-concurrency result is real."
        )
    for _ in range(WARMUP_REQUESTS):
        synthesize_once()
    result = {
        "service": "kokoro",
        "voice": VOICE,
        "warmup_requests": WARMUP_REQUESTS,
        "requests_per_level": REQUESTS_PER_LEVEL,
        "results": [benchmark_level(level) for level in CONCURRENCY_LEVELS],
    }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
