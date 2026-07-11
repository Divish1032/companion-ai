#!/usr/bin/env python3
"""Compare nearest-memory rankings for full precision and INT8 embeddings."""

from __future__ import annotations

import argparse
import json
import math

from sentence_transformers import SentenceTransformer


def cosine(left: list[float], right: list[float]) -> float:
    numerator = sum(a * b for a, b in zip(left, right, strict=True))
    left_norm = math.sqrt(sum(value * value for value in left))
    right_norm = math.sqrt(sum(value * value for value in right))
    return numerator / (left_norm * right_norm)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshot", required=True)
    parser.add_argument("--int8-file", default="onnx/model_qint8_arm64.onnx")
    args = parser.parse_args()

    memories = [
        "office manager pressure recurring work stress",
        "preferred language Hindi replies",
        "preferred name Rahul",
        "quiet evening music routine",
        "goal focus on studies",
        "friend visit yesterday",
    ]
    queries = [
        "आज ऑफिस में मैनेजर का दबाव",
        "मुझे किस भाषा में जवाब पसंद है",
        "मेरा नाम क्या है",
        "शाम को संगीत सुनना",
        "पढ़ाई पर ध्यान देना",
        "कल दोस्त से मिलना",
    ]
    full = SentenceTransformer(args.snapshot)
    quantized = SentenceTransformer(
        args.snapshot,
        backend="onnx",
        model_kwargs={
            "provider": "CPUExecutionProvider",
            "file_name": args.int8_file,
            "export": False,
        },
    )
    full_memory = full.encode_document(memories, normalize_embeddings=True)
    full_query = full.encode_query(queries, normalize_embeddings=True)
    int8_memory = quantized.encode_document(memories, normalize_embeddings=True)
    int8_query = quantized.encode_query(queries, normalize_embeddings=True)
    full_rankings = [
        max(range(len(memories)), key=lambda index: cosine(query, full_memory[index]))
        for query in full_query
    ]
    int8_rankings = [
        max(range(len(memories)), key=lambda index: cosine(query, int8_memory[index]))
        for query in int8_query
    ]
    print(
        json.dumps(
            {
                "queries": len(queries),
                "top1_agreement": sum(a == b for a, b in zip(full_rankings, int8_rankings, strict=True)),
                "full_top1": full_rankings,
                "int8_top1": int8_rankings,
                "vector_dimension": len(full_memory[0]),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
