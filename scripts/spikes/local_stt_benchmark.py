#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import time
import wave
from pathlib import Path

from faster_whisper import WhisperModel
from vosk import KaldiRecognizer, Model as VoskModel


def audio_duration_seconds(path: Path) -> float:
    with wave.open(str(path), "rb") as wf:
        return wf.getnframes() / float(wf.getframerate())


def run_faster_whisper(files: list[Path], model_name: str) -> list[dict]:
    model = WhisperModel(model_name, device="cpu", compute_type="int8")
    results = []
    for wav in files:
        started = time.perf_counter()
        segments, info = model.transcribe(
            str(wav),
            language="hi",
            vad_filter=False,
            beam_size=5,
        )
        first_segment_ms = None
        texts = []
        segment_count = 0
        for segment in segments:
            segment_count += 1
            texts.append(segment.text.strip())
            if first_segment_ms is None:
                first_segment_ms = round((time.perf_counter() - started) * 1000, 1)
        total_ms = round((time.perf_counter() - started) * 1000, 1)
        results.append(
            {
                "engine": "faster-whisper",
                "model": model_name,
                "file": wav.name,
                "duration_s": round(audio_duration_seconds(wav), 2),
                "total_ms": total_ms,
                "first_segment_ms": first_segment_ms,
                "segment_count": segment_count,
                "detected_language": getattr(info, "language", None),
                "text": " ".join(t for t in texts if t).strip(),
                "segments": texts,
            }
        )
    return results


def run_vosk(files: list[Path], model_path: Path) -> list[dict]:
    model = VoskModel(str(model_path))
    results = []
    chunk_frames = 4000
    for wav in files:
        with wave.open(str(wav), "rb") as wf:
            recognizer = KaldiRecognizer(model, wf.getframerate())
            recognizer.SetWords(False)
            started = time.perf_counter()
            first_result_ms = None
            pieces = []
            result_count = 0
            while True:
                data = wf.readframes(chunk_frames)
                if not data:
                    break
                if recognizer.AcceptWaveform(data):
                    result = json.loads(recognizer.Result())
                    text = result.get("text", "").strip()
                    if text:
                        result_count += 1
                        pieces.append(text)
                        if first_result_ms is None:
                            first_result_ms = round((time.perf_counter() - started) * 1000, 1)
            final_result = json.loads(recognizer.FinalResult())
            final_text = final_result.get("text", "").strip()
            if final_text:
                pieces.append(final_text)
            total_ms = round((time.perf_counter() - started) * 1000, 1)
        results.append(
            {
                "engine": "vosk",
                "model": model_path.name,
                "file": wav.name,
                "duration_s": round(audio_duration_seconds(wav), 2),
                "total_ms": total_ms,
                "first_segment_ms": first_result_ms,
                "segment_count": result_count + (1 if final_text else 0),
                "text": " ".join(pieces).strip(),
                "segments": pieces,
            }
        )
    return results


def run_whisper_cpp(files: list[Path], binary: Path, model_path: Path, out_dir: Path) -> list[dict]:
    results = []
    for wav in files:
        out_base = out_dir / wav.stem
        json_path = out_base.with_suffix(".json")
        cmd = [
            str(binary),
            "-m",
            str(model_path),
            "-l",
            "hi",
            "-f",
            str(wav),
            "-oj",
            "-of",
            str(out_base),
            "-np",
            "-nt",
            "-ng",
        ]
        started = time.perf_counter()
        proc = subprocess.run(cmd, capture_output=True, text=True)
        total_ms = round((time.perf_counter() - started) * 1000, 1)
        if proc.returncode != 0:
            results.append(
                {
                    "engine": "whisper.cpp",
                    "model": model_path.name,
                    "file": wav.name,
                    "duration_s": round(audio_duration_seconds(wav), 2),
                    "total_ms": total_ms,
                    "error": proc.stderr[-1000:],
                }
            )
            continue
        payload = json.loads(json_path.read_text(encoding="utf-8"))
        segments = [seg.get("text", "").strip() for seg in payload.get("transcription", []) if seg.get("text")]
        results.append(
            {
                "engine": "whisper.cpp",
                "model": model_path.name,
                "file": wav.name,
                "duration_s": round(audio_duration_seconds(wav), 2),
                "total_ms": total_ms,
                "first_segment_ms": None,
                "segment_count": len(segments),
                "text": " ".join(segments).strip(),
                "segments": segments,
            }
        )
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--wav-dir", required=True)
    parser.add_argument("--files", nargs="+", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--faster-whisper-model", default="base")
    parser.add_argument("--vosk-model-path", required=True)
    parser.add_argument("--whisper-cpp-bin", required=True)
    parser.add_argument("--whisper-cpp-model", required=True)
    args = parser.parse_args()

    wav_dir = Path(args.wav_dir)
    files = [wav_dir / f for f in args.files]
    out_json = Path(args.output_json)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    whisper_out_dir = out_json.parent / "whisper_cpp_outputs"
    whisper_out_dir.mkdir(parents=True, exist_ok=True)

    results = {
        "faster_whisper": run_faster_whisper(files, args.faster_whisper_model),
        "whisper_cpp": run_whisper_cpp(
            files,
            Path(args.whisper_cpp_bin),
            Path(args.whisper_cpp_model),
            whisper_out_dir,
        ),
        "vosk": run_vosk(files, Path(args.vosk_model_path)),
    }
    out_json.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
