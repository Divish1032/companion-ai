#!/usr/bin/env python3
"""Compare PyTorch and ONNX EmbeddingGemma vectors without printing text."""

from __future__ import annotations

import json
import math
import statistics
import argparse

from sentence_transformers import SentenceTransformer


def cosine(left: list[float], right: list[float]) -> float:
    numerator = sum(a * b for a, b in zip(left, right, strict=True))
    left_norm = math.sqrt(sum(value * value for value in left))
    right_norm = math.sqrt(sum(value * value for value in right))
    return numerator / (left_norm * right_norm)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="google/embeddinggemma-300m")
    parser.add_argument("--onnx-file", default="onnx/model.onnx")
    args = parser.parse_args()
    texts = [
        "मेरा नाम राहुल है।",
        "मुझे हिंदी में जवाब पसंद है।",
        "आज ऑफिस में मैनेजर ने बहुत दबाव दिया।",
        "कल मैं अपने दोस्त से मिलने गया था।",
        "मेरा मूड आज थोड़ा खराब है।",
        "मुझे शाम को शांत संगीत सुनना पसंद है।",
        "यह एक सुरक्षित परीक्षण वाक्य है।",
        "मुझे अपनी पढ़ाई पर ध्यान देना है।",
    ]
    pytorch = SentenceTransformer(args.model)
    onnx = SentenceTransformer(
        args.model,
        backend="onnx",
        model_kwargs={
            "provider": "CPUExecutionProvider",
            "file_name": args.onnx_file,
            "export": False,
        },
    )
    pytorch_vectors = pytorch.encode_document(texts, normalize_embeddings=True)
    onnx_vectors = onnx.encode_document(texts, normalize_embeddings=True)
    similarities = [
        cosine([float(value) for value in left], [float(value) for value in right])
        for left, right in zip(pytorch_vectors, onnx_vectors, strict=True)
    ]
    print(
        json.dumps(
            {
                "samples": len(similarities),
                "cosine_min": round(min(similarities), 8),
                "cosine_mean": round(statistics.mean(similarities), 8),
                "cosine_max": round(max(similarities), 8),
                "dimension": len(pytorch_vectors[0]),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
