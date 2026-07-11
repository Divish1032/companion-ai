#!/usr/bin/env python3
"""Export an ARM64 dynamic-INT8 EmbeddingGemma ONNX artifact into the model cache."""

from sentence_transformers import SentenceTransformer, export_dynamic_quantized_onnx_model


model = SentenceTransformer(
    "google/embeddinggemma-300m",
    backend="onnx",
    model_kwargs={"provider": "CPUExecutionProvider"},
)
export_dynamic_quantized_onnx_model(
    model=model,
    quantization_config="arm64",
    model_name_or_path="/models/huggingface/embeddinggemma-onnx-int8",
)
print("int8_export_complete")
