#!/usr/bin/env python3
"""Create the complete persisted FP32 ONNX Sentence Transformer artifact."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from sentence_transformers import SentenceTransformer


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="google/embeddinggemma-300m")
    parser.add_argument(
        "--output",
        default="/models/huggingface/embeddinggemma-onnx-fp32",
    )
    args = parser.parse_args()
    output = Path(args.output)
    artifact = output / "onnx" / "model.onnx"
    if artifact.is_file() and (output / "modules.json").is_file():
        print(json.dumps({"status": "exists", "path": str(output)}))
        return

    model = SentenceTransformer(
        args.model,
        backend="onnx",
        model_kwargs={"provider": "CPUExecutionProvider"},
    )
    model.save_pretrained(output)
    if not artifact.is_file():
        raise RuntimeError("ONNX artifact was not written to the expected path")
    print(json.dumps({"status": "created", "path": str(output)}))


if __name__ == "__main__":
    main()
