from __future__ import annotations

import asyncio
import json
import time
import threading
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Literal, Protocol


EmbeddingInputType = Literal["query", "document"]


class ModelServingUnavailable(RuntimeError):
    """Raised when optional local model serving cannot safely handle a request."""


class EmbeddingModel(Protocol):
    def encode(
        self, texts: Sequence[str], *, input_type: EmbeddingInputType
    ) -> list[list[float]]: ...


class RerankerModel(Protocol):
    def score(self, query: str, candidates: Sequence[str]) -> list[float]: ...


class PlannerModel(Protocol):
    def plan(self, prompt: str) -> str: ...


@dataclass(frozen=True)
class RetrievalPlan:
    need_memory: bool
    route: Literal["none", "core_profile", "semantic", "episodic", "summary", "broad_safe"]
    memory_types: tuple[str, ...]
    entities: tuple[str, ...]
    time_hint: Literal["recent", "historical", "none"]
    top_k: int


class SentenceTransformersEmbeddingModel:
    def __init__(
        self,
        model_name: str,
        *,
        dimension: int,
        backend: str = "pytorch",
        model_path: str = "",
    ) -> None:
        try:
            from sentence_transformers import SentenceTransformer
        except ImportError as error:  # pragma: no cover - environment dependent
            raise ModelServingUnavailable("sentence-transformers is not installed") from error
        try:
            if backend == "onnx":
                self._model = SentenceTransformer(
                    model_path,
                    backend="onnx",
                    model_kwargs={
                        "provider": "CPUExecutionProvider",
                        "file_name": "onnx/model.onnx",
                        "export": False,
                    },
                    # Transformers 4.57.x can misclassify a local non-Mistral
                    # artifact. EmbeddingGemma is gemma3_text, so the Mistral
                    # regex mutation is inapplicable and must stay disabled.
                    processor_kwargs={"fix_mistral_regex": False},
                )
            else:
                self._model = SentenceTransformer(
                    model_name,
                    processor_kwargs={"fix_mistral_regex": False},
                )
        except Exception as error:  # pragma: no cover - model download/runtime dependent
            raise ModelServingUnavailable("embedding model could not be loaded") from error
        self._dimension = dimension

    def encode(self, texts: Sequence[str], *, input_type: EmbeddingInputType) -> list[list[float]]:
        try:
            encode = (
                self._model.encode_query if input_type == "query" else self._model.encode_document
            )
            vectors = encode(list(texts), truncate_dim=self._dimension, normalize_embeddings=True)
            return [[float(value) for value in vector] for vector in vectors]
        except Exception as error:  # pragma: no cover - model runtime dependent
            raise ModelServingUnavailable("embedding inference failed") from error


class SentenceTransformersRerankerModel:
    def __init__(self, model_name: str) -> None:
        try:
            from sentence_transformers import CrossEncoder
        except ImportError as error:  # pragma: no cover - environment dependent
            raise ModelServingUnavailable("sentence-transformers is not installed") from error
        try:
            self._model = CrossEncoder(
                model_name,
                prompts={"memory": "Does this memory help answer the user's current turn?"},
                default_prompt_name="memory",
            )
        except Exception as error:  # pragma: no cover - model download/runtime dependent
            raise ModelServingUnavailable("reranker model could not be loaded") from error

    def score(self, query: str, candidates: Sequence[str]) -> list[float]:
        try:
            scores = self._model.predict([(query, candidate) for candidate in candidates])
            return [float(score) for score in scores]
        except Exception as error:  # pragma: no cover - model runtime dependent
            raise ModelServingUnavailable("reranker inference failed") from error


class TransformersPlannerModel:
    def __init__(self, model_name: str) -> None:
        try:
            from transformers import pipeline
        except ImportError as error:  # pragma: no cover - environment dependent
            raise ModelServingUnavailable("transformers is not installed") from error
        try:
            self._pipeline = pipeline("text-generation", model=model_name, device_map="auto")
        except Exception as error:  # pragma: no cover - model download/runtime dependent
            raise ModelServingUnavailable("planner model could not be loaded") from error

    def plan(self, prompt: str) -> str:
        try:
            result = self._pipeline(
                prompt,
                max_new_tokens=120,
                do_sample=False,
                return_full_text=False,
            )
            return str(result[0]["generated_text"])
        except Exception as error:  # pragma: no cover - model runtime dependent
            raise ModelServingUnavailable("planner inference failed") from error


class ModelServingService:
    """Stateless compute facade; it deliberately retains no request text or vectors."""

    def __init__(
        self,
        *,
        embedding_enabled: bool,
        embedding_model_name: str,
        embedding_dimension: int,
        embedding_backend: str = "pytorch",
        embedding_model_path: str = "",
        reranker_enabled: bool,
        reranker_model_name: str,
        planner_enabled: bool,
        planner_model_name: str,
        embedding_model_revision: str = "",
    ) -> None:
        self.embedding_enabled = embedding_enabled
        self.embedding_model_name = embedding_model_name
        self.embedding_model_revision = embedding_model_revision
        self.embedding_dimension = embedding_dimension
        self.embedding_backend = embedding_backend
        self.embedding_model_path = embedding_model_path
        self.reranker_enabled = reranker_enabled
        self.reranker_model_name = reranker_model_name
        self.planner_enabled = planner_enabled
        self.planner_model_name = planner_model_name
        self._embedding_model: EmbeddingModel | None = None
        self._reranker_model: RerankerModel | None = None
        self._planner_model: PlannerModel | None = None
        self._embedding_lock = threading.Lock()
        self._reranker_lock = threading.Lock()
        self._planner_lock = threading.Lock()
        self._embedding_state = "loading" if embedding_enabled else "disabled"
        self._embedding_error_type: str | None = None
        self._active_embedding_backend: str | None = None

    def embedding_readiness(self) -> dict[str, object]:
        return {
            "enabled": self.embedding_enabled,
            "state": self._embedding_state,
            "model": self.embedding_model_name,
            "revision": self.embedding_model_revision,
            "dimension": self.embedding_dimension,
            "configured_backend": self.embedding_backend,
            "active_backend": self._active_embedding_backend,
            "error_type": self._embedding_error_type,
        }

    async def warm_up(self) -> None:
        """Load enabled models before serving model-dependent requests."""
        if not self.embedding_enabled or self._embedding_state == "ready":
            return
        started = time.perf_counter()
        try:
            await asyncio.to_thread(self._load_embedding_model, self.embedding_backend)
        except Exception as error:  # pragma: no cover - model/runtime dependent
            self._embedding_error_type = type(error).__name__
            self._embedding_state = "failed"
            print(
                "memory_model_readiness",
                {
                    "model": self.embedding_model_name,
                    "revision": self.embedding_model_revision,
                    "state": self._embedding_state,
                    "configured_backend": self.embedding_backend,
                    "error_type": self._embedding_error_type,
                    "cold_load_ms": round((time.perf_counter() - started) * 1000),
                },
                flush=True,
            )
            return
        self._active_embedding_backend = self.embedding_backend
        self._embedding_state = "ready"
        self._embedding_error_type = None
        print(
            "memory_model_readiness",
            {
                "model": self.embedding_model_name,
                "revision": self.embedding_model_revision,
                "state": self._embedding_state,
                "dimension": self.embedding_dimension,
                "active_backend": self._active_embedding_backend,
                "cold_load_ms": round((time.perf_counter() - started) * 1000),
                "model_cache_bytes": _artifact_size_bytes(self.embedding_model_path),
            },
            flush=True,
        )

    async def embed(self, texts: list[str], *, input_type: EmbeddingInputType) -> list[list[float]]:
        if not self.embedding_enabled:
            raise ModelServingUnavailable("embedding serving is disabled")
        if self._embedding_state != "ready":
            raise ModelServingUnavailable(f"embedding serving is {self._embedding_state}")
        started = time.perf_counter()
        result = await asyncio.to_thread(self._embed_sync, texts, input_type)
        print(
            "memory_model_inference",
            {
                "operation": "embedding",
                "input_count": len(texts),
                "warm_inference_ms": round((time.perf_counter() - started) * 1000),
                "model": self.embedding_model_name,
                "dimension": self.embedding_dimension,
                "backend": self._active_embedding_backend,
            },
            flush=True,
        )
        return result

    async def rerank(self, query: str, candidates: list[str]) -> list[float]:
        if not self.reranker_enabled:
            raise ModelServingUnavailable("reranker serving is disabled")
        return await asyncio.to_thread(self._rerank_sync, query, candidates)

    async def plan(self, text: str) -> RetrievalPlan:
        if not self.planner_enabled:
            raise ModelServingUnavailable("planner serving is disabled")
        raw = await asyncio.to_thread(self._plan_sync, _planner_prompt(text))
        return parse_retrieval_plan(raw)

    def _embed_sync(self, texts: list[str], input_type: EmbeddingInputType) -> list[list[float]]:
        self._load_embedding_model(self._active_embedding_backend or self.embedding_backend)
        with self._embedding_lock:
            if self._embedding_model is None:  # pragma: no cover - defensive guard
                raise ModelServingUnavailable("embedding model is not ready")
            return self._embedding_model.encode(texts, input_type=input_type)

    def _load_embedding_model(self, backend: str) -> None:
        with self._embedding_lock:
            if self._embedding_model is None:
                if backend == "onnx":
                    _validate_embedding_artifact_revision(
                        model_path=self.embedding_model_path,
                        expected_model=self.embedding_model_name,
                        expected_revision=self.embedding_model_revision,
                    )
                self._embedding_model = SentenceTransformersEmbeddingModel(
                    self.embedding_model_name,
                    dimension=self.embedding_dimension,
                    backend=backend,
                    model_path=self.embedding_model_path,
                )

    def _rerank_sync(self, query: str, candidates: list[str]) -> list[float]:
        with self._reranker_lock:
            if self._reranker_model is None:
                self._reranker_model = SentenceTransformersRerankerModel(self.reranker_model_name)
            return self._reranker_model.score(query, candidates)

    def _plan_sync(self, prompt: str) -> str:
        with self._planner_lock:
            if self._planner_model is None:
                self._planner_model = TransformersPlannerModel(self.planner_model_name)
            return self._planner_model.plan(prompt)


def _validate_embedding_artifact_revision(
    *,
    model_path: str,
    expected_model: str,
    expected_revision: str,
) -> None:
    metadata_path = Path(model_path) / "companion_model_revision.json"
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ModelServingUnavailable(
            "embedding artifact revision metadata is unavailable"
        ) from error
    if (
        not expected_revision
        or metadata.get("model") != expected_model
        or metadata.get("revision") != expected_revision
    ):
        raise ModelServingUnavailable("embedding artifact revision does not match configuration")


def _artifact_size_bytes(path: str) -> int:
    try:
        return sum(item.stat().st_size for item in Path(path).rglob("*") if item.is_file())
    except OSError:
        return 0


def parse_retrieval_plan(raw: str) -> RetrievalPlan:
    """Accept exactly one bounded JSON object; no prose or permissive repair."""
    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as error:
        raise ModelServingUnavailable("planner returned invalid JSON") from error
    if not isinstance(decoded, dict) or set(decoded) != {
        "need_memory",
        "route",
        "memory_types",
        "entities",
        "time_hint",
        "top_k",
    }:
        raise ModelServingUnavailable("planner returned an invalid schema")
    need_memory = decoded["need_memory"]
    route = decoded["route"]
    memory_types = decoded["memory_types"]
    entities = decoded["entities"]
    time_hint = decoded["time_hint"]
    top_k = decoded["top_k"]
    allowed_routes = {"none", "core_profile", "semantic", "episodic", "summary", "broad_safe"}
    allowed_types = {"core_profile", "semantic", "episodic", "session_summary", "procedural"}
    if (
        not isinstance(need_memory, bool)
        or route not in allowed_routes
        or not isinstance(memory_types, list)
        or not all(isinstance(item, str) and item in allowed_types for item in memory_types)
        or len(memory_types) > 3
        or not isinstance(entities, list)
        or not all(isinstance(item, str) and 1 <= len(item) <= 48 for item in entities)
        or len(entities) > 4
        or time_hint not in {"recent", "historical", "none"}
        or not isinstance(top_k, int)
        or not 0 <= top_k <= 6
        or (not need_memory and (route != "none" or top_k != 0))
        or (need_memory and (route == "none" or top_k == 0))
    ):
        raise ModelServingUnavailable("planner returned unsafe values")
    return RetrievalPlan(
        need_memory=need_memory,
        route=route,
        memory_types=tuple(memory_types),
        entities=tuple(entities),
        time_hint=time_hint,
        top_k=top_k,
    )


def _planner_prompt(text: str) -> str:
    return (
        "Return only one JSON object with exactly these keys: need_memory, route, memory_types, "
        "entities, time_hint, top_k. Do not recall or infer facts. Choose route from none, "
        "core_profile, semantic, episodic, summary, broad_safe; time_hint from recent, "
        "historical, none. memory_types may contain only core_profile, semantic, episodic, "
        "session_summary, procedural. Use no memory for greetings or acknowledgements. "
        f"User turn: {text}"
    )
