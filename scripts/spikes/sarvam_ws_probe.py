#!/usr/bin/env python3
import argparse
import asyncio
import base64
import json
import os
import tempfile
import time
import wave
from pathlib import Path
from urllib.parse import urlencode

import websockets
from dotenv import load_dotenv


def load_api_key() -> str:
    load_dotenv()
    api_key = os.getenv("SARVAM_API_KEY", "").strip()
    if not api_key:
        raise SystemExit("SARVAM_API_KEY is missing from env or .env")
    return api_key


def split_wav(path: Path, chunk_ms: int) -> tuple[list[bytes], int, int]:
    with wave.open(str(path), "rb") as wf:
        nchannels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        framerate = wf.getframerate()
        frames = wf.getnframes()
        pcm = wf.readframes(frames)

    bytes_per_frame = nchannels * sampwidth
    frames_per_chunk = max(1, int(framerate * chunk_ms / 1000))
    chunks: list[bytes] = []

    for frame_start in range(0, frames, frames_per_chunk):
        frame_end = min(frames, frame_start + frames_per_chunk)
        start = frame_start * bytes_per_frame
        end = frame_end * bytes_per_frame
        pcm_chunk = pcm[start:end]
        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmp.close()
        with wave.open(tmp.name, "wb") as out:
            out.setnchannels(nchannels)
            out.setsampwidth(sampwidth)
            out.setframerate(framerate)
            out.writeframes(pcm_chunk)
        chunk_bytes = Path(tmp.name).read_bytes()
        Path(tmp.name).unlink(missing_ok=True)
        chunks.append(chunk_bytes)

    return chunks, framerate, frames


async def _reader(ws, started_at: float, sink: list[dict]):
    try:
        async for raw in ws:
            now = time.perf_counter()
            entry = {
                "elapsed_ms": round((now - started_at) * 1000, 1),
                "raw": raw,
            }
            try:
                entry["json"] = json.loads(raw)
            except Exception:
                entry["json"] = None
            sink.append(entry)
    except websockets.ConnectionClosed:
        return


async def probe_stt(api_key: str, audio_path: Path, chunk_ms: int) -> dict:
    chunks, sample_rate, total_frames = split_wav(audio_path, chunk_ms)
    query = urlencode(
        {
            "language-code": "hi-IN",
            "model": "saaras:v3",
            "mode": "transcribe",
            "sample_rate": str(sample_rate),
            "vad_signals": "true",
            "high_vad_sensitivity": "true",
            "flush_signal": "true",
        }
    )
    uri = f"wss://api.sarvam.ai/speech-to-text/ws?{query}"
    events: list[dict] = []

    started_at = time.perf_counter()
    async with websockets.connect(
        uri,
        additional_headers={"Api-Subscription-Key": api_key},
        max_size=8 * 1024 * 1024,
    ) as ws:
        reader = asyncio.create_task(_reader(ws, started_at, events))
        for idx, chunk in enumerate(chunks, start=1):
            payload = {
                "audio": {
                    "data": base64.b64encode(chunk).decode("ascii"),
                    "sample_rate": str(sample_rate),
                    "encoding": "audio/wav",
                }
            }
            await ws.send(json.dumps(payload))
            events.append(
                {
                    "elapsed_ms": round((time.perf_counter() - started_at) * 1000, 1),
                    "client": "sent_audio_chunk",
                    "chunk_index": idx,
                    "chunk_count": len(chunks),
                }
            )
            await asyncio.sleep(chunk_ms / 1000)

        sent_done_ms = round((time.perf_counter() - started_at) * 1000, 1)
        await ws.send(json.dumps({"type": "flush"}))
        flush_sent_ms = round((time.perf_counter() - started_at) * 1000, 1)
        events.append({"elapsed_ms": flush_sent_ms, "client": "sent_flush"})
        await asyncio.sleep(6)
        await ws.close()
        await reader

    transcripts = []
    vad_events = []
    errors = []
    for item in events:
        msg = item.get("json")
        if not msg:
            continue
        if msg.get("type") == "data":
            transcripts.append(item)
        elif msg.get("type") == "events":
            vad_events.append(item)
        elif msg.get("type") == "error":
            errors.append(item)

    first_transcript_ms = next((x["elapsed_ms"] for x in transcripts), None)
    transcript_before_flush = any(x["elapsed_ms"] < flush_sent_ms for x in transcripts)
    transcript_before_stream_end = any(x["elapsed_ms"] < sent_done_ms for x in transcripts)
    response_types = sorted(
        {
            item["json"].get("type")
            for item in events
            if item.get("json") and isinstance(item["json"], dict)
        }
    )

    return {
        "audio_path": str(audio_path),
        "sample_rate": sample_rate,
        "total_frames": total_frames,
        "chunk_ms": chunk_ms,
        "chunk_count": len(chunks),
        "sent_done_ms": sent_done_ms,
        "flush_sent_ms": flush_sent_ms,
        "response_types": response_types,
        "first_transcript_ms": first_transcript_ms,
        "transcript_before_flush": transcript_before_flush,
        "transcript_before_stream_end": transcript_before_stream_end,
        "transcript_count": len(transcripts),
        "vad_event_count": len(vad_events),
        "error_count": len(errors),
        "transcripts": transcripts,
        "vad_events": vad_events,
        "errors": errors,
        "all_events": events,
    }


async def probe_tts(api_key: str, model: str, out_dir: Path) -> dict:
    uri = (
        "wss://api.sarvam.ai/text-to-speech/ws?"
        + urlencode({"model": model, "send_completion_event": "true"})
    )
    events: list[dict] = []
    audio_parts: list[bytes] = []
    text_chunks = [
        "नमस्ते, मैं आपकी बात समझ रहा हूँ।",
        "थोड़ा सा रुकिए, मैं जवाब तैयार कर रहा हूँ।",
    ]

    started_at = time.perf_counter()
    first_text_sent_ms = None
    flush_sent_ms = None
    close_info = None
    try:
        async with websockets.connect(
            uri,
            additional_headers={"Api-Subscription-Key": api_key},
            max_size=8 * 1024 * 1024,
        ) as ws:
            reader = asyncio.create_task(_reader(ws, started_at, events))
            config = {
                "type": "config",
                "data": {
                    "speaker": "shubh",
                    "target_language_code": "hi-IN",
                    "pace": 1.0,
                    "min_buffer_size": 20,
                    "max_chunk_length": 80,
                    "output_audio_codec": "mp3",
                    "output_audio_bitrate": "128k",
                },
            }
            await ws.send(json.dumps(config))
            events.append({"elapsed_ms": round((time.perf_counter() - started_at) * 1000, 1), "client": "sent_config"})
            for chunk in text_chunks:
                msg = {"type": "text", "data": {"text": chunk}}
                await ws.send(json.dumps(msg))
                ts = round((time.perf_counter() - started_at) * 1000, 1)
                if first_text_sent_ms is None:
                    first_text_sent_ms = ts
                events.append({"elapsed_ms": ts, "client": "sent_text", "text": chunk})
                await asyncio.sleep(0.15)

            await ws.send(json.dumps({"type": "flush"}))
            flush_sent_ms = round((time.perf_counter() - started_at) * 1000, 1)
            events.append({"elapsed_ms": flush_sent_ms, "client": "sent_flush"})
            await asyncio.sleep(6)
            await ws.close()
            await reader
    except websockets.ConnectionClosed as exc:
        close_info = {"code": exc.code, "reason": exc.reason}
        events.append(
            {
                "elapsed_ms": round((time.perf_counter() - started_at) * 1000, 1),
                "client": "connection_closed",
                "code": exc.code,
                "reason": exc.reason,
            }
        )

    audio_messages = []
    event_messages = []
    errors = []
    for item in events:
        msg = item.get("json")
        if not msg:
            continue
        if msg.get("type") == "audio":
            audio_messages.append(item)
            try:
                audio_parts.append(base64.b64decode(msg["data"]["audio"]))
            except Exception:
                pass
        elif msg.get("type") == "event":
            event_messages.append(item)
        elif msg.get("type") == "error":
            errors.append(item)

    output_path = out_dir / f"tts_{model.replace(':', '_')}.mp3"
    if audio_parts:
        output_path.write_bytes(b"".join(audio_parts))

    first_audio_ms = next((x["elapsed_ms"] for x in audio_messages), None)
    final_event_ms = next(
        (
            x["elapsed_ms"]
            for x in event_messages
            if x.get("json", {}).get("data", {}).get("event_type") == "final"
        ),
        None,
    )

    return {
        "model": model,
        "first_text_sent_ms": first_text_sent_ms,
        "flush_sent_ms": flush_sent_ms,
        "first_audio_ms": first_audio_ms,
        "first_audio_after_first_text_ms": None
        if first_audio_ms is None or first_text_sent_ms is None
        else round(first_audio_ms - first_text_sent_ms, 1),
        "final_event_ms": final_event_ms,
        "audio_chunk_count": len(audio_messages),
        "event_count": len(event_messages),
        "error_count": len(errors),
        "close_info": close_info,
        "output_path": str(output_path) if audio_parts else None,
        "audio_messages": audio_messages,
        "event_messages": event_messages,
        "errors": errors,
        "all_events": events,
    }


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio-path", required=True)
    parser.add_argument("--chunk-ms", type=int, default=200)
    parser.add_argument("--output-json", required=True)
    args = parser.parse_args()

    api_key = load_api_key()
    audio_path = Path(args.audio_path).resolve()
    out_json = Path(args.output_json).resolve()
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_dir = out_json.parent

    result = {"stt": None, "tts": {}}
    try:
        result["stt"] = await probe_stt(api_key, audio_path, args.chunk_ms)
    except Exception as exc:
        result["stt"] = {"probe_error": repr(exc)}

    for model in ("bulbul:v2", "bulbul:v3"):
        try:
            result["tts"][model] = await probe_tts(api_key, model, out_dir)
        except Exception as exc:
            result["tts"][model] = {"probe_error": repr(exc)}
    out_json.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
