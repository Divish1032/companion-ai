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
        "--revision",
        default="57c266a740f537b4dc058e1b0cda161fd15afa75",
    )
    parser.add_argument(
        "--output",
        default="/models/huggingface/embeddinggemma-onnx-fp32-r57c266a7",
    )
    args = parser.parse_args()
    output = Path(args.output)
    artifact = output / "onnx" / "model.onnx"
    revision_metadata = output / "companion_model_revision.json"
    if artifact.is_file() and (output / "modules.json").is_file():
        if not revision_metadata.is_file():
            raise RuntimeError("existing ONNX artifact has no revision metadata")
        recorded = json.loads(revision_metadata.read_text(encoding="utf-8"))
        if recorded.get("model") != args.model or recorded.get("revision") != args.revision:
            raise RuntimeError("existing ONNX artifact revision does not match configuration")
        print(
            json.dumps(
                {
                    "status": "exists",
                    "path": str(output),
                    "model": args.model,
                    "revision": args.revision,
                    "revision_verified": True,
                }
            )
        )
        return

    model = SentenceTransformer(
        args.model,
        revision=args.revision,
        backend="onnx",
        model_kwargs={"provider": "CPUExecutionProvider"},
        processor_kwargs={"fix_mistral_regex": False},
    )
    model.save_pretrained(output)
    if not artifact.is_file():
        raise RuntimeError("ONNX artifact was not written to the expected path")
    revision_metadata.write_text(
        json.dumps({"model": args.model, "revision": args.revision}, indent=2),
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "status": "created",
                "path": str(output),
                "model": args.model,
                "revision": args.revision,
            }
        )
    )


if __name__ == "__main__":
    main()
