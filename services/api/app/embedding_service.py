from __future__ import annotations

import hashlib
import math


DEFAULT_EMBEDDING_MODEL = "embeddinggemma-stateless-dev"
DEFAULT_EMBEDDING_DIMENSION = 256


def embed_texts(
    texts: list[str],
    *,
    dimension: int = DEFAULT_EMBEDDING_DIMENSION,
) -> list[list[float]]:
    return [_embed_text(text, dimension=dimension) for text in texts]


def rerank(query: str, candidates: list[str]) -> list[float]:
    query_terms = _terms(query)
    scores: list[float] = []
    for candidate in candidates:
        candidate_terms = _terms(candidate)
        overlap = len(query_terms & candidate_terms)
        union = len(query_terms | candidate_terms) or 1
        scores.append(overlap / union)
    return scores


def _embed_text(text: str, *, dimension: int) -> list[float]:
    vector = [0.0] * dimension
    for term in _terms(text):
        digest = hashlib.sha256(term.encode("utf-8")).digest()
        bucket = int.from_bytes(digest[:4], "big") % dimension
        sign = 1.0 if digest[4] % 2 == 0 else -1.0
        vector[bucket] += sign
    norm = math.sqrt(sum(value * value for value in vector))
    if norm == 0:
        return vector
    return [round(value / norm, 6) for value in vector]


def _terms(text: str) -> set[str]:
    normalized = (
        text.casefold()
        .replace("ऑफिस", " office ")
        .replace("काम", " work ")
        .replace("मैनेजर", " manager ")
        .replace("परेशान", " stress ")
        .replace("kaam", " work ")
        .replace("pareshan", " stress ")
        .replace("naam", " name ")
        .replace("pasand", " like ")
        .replace("yaad", " remember ")
    )
    return {term for term in normalized.split() if len(term) >= 2}
