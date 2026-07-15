import asyncio
import json
from pathlib import Path

import pytest

from app.embedding_service import ModelServingService, ModelServingUnavailable


class _FakeEmbeddingModel:
    def __init__(
        self,
        model_name: str,
        *,
        dimension: int,
        backend: str = "pytorch",
        model_path: str = "",
    ) -> None:
        self.dimension = dimension

    def encode(self, texts, *, input_type):  # noqa: ANN001
        return [[0.1] * self.dimension for _ in texts]


def _service(backend: str = "pytorch") -> ModelServingService:
    return ModelServingService(
        embedding_enabled=True,
        embedding_model_name="test-model",
        embedding_dimension=4,
        embedding_backend=backend,
        embedding_model_path="/tmp/embedding-model",
        reranker_enabled=False,
        reranker_model_name="unused",
        planner_enabled=False,
        planner_model_name="unused",
        embedding_model_revision="revision-123",
    )


def test_embedding_warmup_makes_model_ready_and_serves(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(
        "app.embedding_service.SentenceTransformersEmbeddingModel",
        _FakeEmbeddingModel,
    )
    service = _service()

    assert service.embedding_readiness()["state"] == "loading"
    assert service.embedding_readiness()["revision"] == "revision-123"
    asyncio.run(service.warm_up())

    assert service.embedding_readiness()["state"] == "ready"
    vectors = asyncio.run(service.embed(["safe test"], input_type="document"))
    assert len(vectors) == 1
    assert len(vectors[0]) == 4


def test_embedding_warmup_failure_fails_closed(monkeypatch) -> None:  # noqa: ANN001
    def fail(*args, **kwargs):  # noqa: ANN002, ANN003
        raise RuntimeError("model unavailable")

    monkeypatch.setattr("app.embedding_service.SentenceTransformersEmbeddingModel", fail)
    service = _service()

    asyncio.run(service.warm_up())

    assert service.embedding_readiness()["state"] == "failed"
    with pytest.raises(ModelServingUnavailable):
        asyncio.run(service.embed(["safe test"], input_type="document"))


def test_disabled_embedding_is_ready_without_model_load() -> None:
    service = ModelServingService(
        embedding_enabled=False,
        embedding_model_name="unused",
        embedding_dimension=4,
        reranker_enabled=False,
        reranker_model_name="unused",
        planner_enabled=False,
        planner_model_name="unused",
    )

    asyncio.run(service.warm_up())

    assert service.embedding_readiness()["state"] == "disabled"


def test_onnx_artifact_revision_must_match(monkeypatch, tmp_path: Path) -> None:  # noqa: ANN001
    monkeypatch.setattr(
        "app.embedding_service.SentenceTransformersEmbeddingModel",
        _FakeEmbeddingModel,
    )
    metadata = tmp_path / "companion_model_revision.json"
    metadata.write_text(
        json.dumps({"model": "test-model", "revision": "wrong-revision"}),
        encoding="utf-8",
    )
    service = ModelServingService(
        embedding_enabled=True,
        embedding_model_name="test-model",
        embedding_model_revision="revision-123",
        embedding_dimension=4,
        embedding_backend="onnx",
        embedding_model_path=str(tmp_path),
        reranker_enabled=False,
        reranker_model_name="unused",
        planner_enabled=False,
        planner_model_name="unused",
    )

    asyncio.run(service.warm_up())

    assert service.embedding_readiness()["state"] == "failed"
    assert service.embedding_readiness()["error_type"] == "ModelServingUnavailable"


def test_onnx_artifact_revision_match_allows_warmup(monkeypatch, tmp_path: Path) -> None:  # noqa: ANN001
    monkeypatch.setattr(
        "app.embedding_service.SentenceTransformersEmbeddingModel",
        _FakeEmbeddingModel,
    )
    metadata = tmp_path / "companion_model_revision.json"
    metadata.write_text(
        json.dumps({"model": "test-model", "revision": "revision-123"}),
        encoding="utf-8",
    )
    service = ModelServingService(
        embedding_enabled=True,
        embedding_model_name="test-model",
        embedding_model_revision="revision-123",
        embedding_dimension=4,
        embedding_backend="onnx",
        embedding_model_path=str(tmp_path),
        reranker_enabled=False,
        reranker_model_name="unused",
        planner_enabled=False,
        planner_model_name="unused",
    )

    asyncio.run(service.warm_up())

    assert service.embedding_readiness()["state"] == "ready"
