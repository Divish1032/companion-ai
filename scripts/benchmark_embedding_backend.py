#!/usr/bin/env python3
"""Benchmark one local Sentence Transformers embedding backend without text output."""

from __future__ import annotations

import argparse
import json
import resource
import statistics
import time


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", choices=("pytorch", "onnx", "openvino"), default="pytorch")
    parser.add_argument("--model", default="google/embeddinggemma-300m")
    parser.add_argument("--samples", type=int, default=30)
    parser.add_argument("--file-name", default=None)
    args = parser.parse_args()

    from sentence_transformers import SentenceTransformer

    model_kwargs = {}
    backend = args.backend
    load_started = time.perf_counter()
    if backend == "pytorch":
        model = SentenceTransformer(args.model)
    else:
        model_kwargs["provider"] = "CPUExecutionProvider" if backend == "onnx" else None
        if args.file_name:
            model_kwargs["file_name"] = args.file_name
            model_kwargs["export"] = False
        model_kwargs = {key: value for key, value in model_kwargs.items() if value is not None}
        model = SentenceTransformer(args.model, backend=backend, model_kwargs=model_kwargs)
    load_ms = (time.perf_counter() - load_started) * 1000

    test_text = "यह एक सुरक्षित परीक्षण वाक्य है।"
    started = time.perf_counter()
    first_vector = model.encode_document([test_text], normalize_embeddings=True)
    first_ms = (time.perf_counter() - started) * 1000

    timings_ms: list[float] = []
    for _ in range(args.samples):
        started = time.perf_counter()
        model.encode_document([test_text], normalize_embeddings=True)
        timings_ms.append((time.perf_counter() - started) * 1000)

    sorted_timings = sorted(timings_ms)
    p95_index = max(0, int(len(sorted_timings) * 0.95) - 1)
    print(
        json.dumps(
            {
                "backend": backend,
                "model": args.model,
                "samples": len(timings_ms),
                "load_ms": round(load_ms, 2),
                "first_inference_ms": round(first_ms, 2),
                "warm_p50_ms": round(statistics.median(timings_ms), 2),
                "warm_p95_ms": round(sorted_timings[p95_index], 2),
                "warm_min_ms": round(sorted_timings[0], 2),
                "warm_max_ms": round(sorted_timings[-1], 2),
                "vector_dimension": len(first_vector[0]),
                "vector_norm": round(sum(float(value) ** 2 for value in first_vector[0]) ** 0.5, 6),
                "max_rss_kb": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
