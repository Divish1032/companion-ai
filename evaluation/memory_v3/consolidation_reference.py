#!/usr/bin/env python3
"""Deterministic offline reference for Memory V3 Task 4 projection transitions."""

from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from copy import deepcopy
from typing import Any


POLICY_VERSION = "consolidation_reference_v1"
SINGLE_CARDINALITY = {
    "preferred_name",
    "works_at",
    "response_language",
    "response_length",
    "support_style",
}
CLAIM_PREDICATES = SINGLE_CARDINALITY | {
    "likes",
    "dislikes",
    "avoids_topic",
    "follows_routine",
    "pursues_goal",
    "holds_value",
}
EPISODE_PREDICATES = {"experienced_event", "event_outcome", "causes_stress"}
THREAD_PREDICATES = {"open_thread", "assistant_commitment"}
RELATION_FAMILIES = {
    "has_relationship": "HAS_RELATIONSHIP",
    "profile_association": "ASSOCIATED_WITH",
    "relationship_association": "ASSOCIATED_WITH",
    "episode_association": "PARTICIPATED_IN",
}
PROJECTABLE_ADMISSIONS = {"auto_admit", "confirmed"}
RECURRENCE_MIN_EPISODES = 3
RECURRENCE_MIN_SESSIONS = 2
RECURRENCE_MIN_SPAN_MS = 24 * 60 * 60 * 1000


def _stable_id(kind: str, *parts: str) -> str:
    encoded = json.dumps(
        [POLICY_VERSION, kind, *parts],
        ensure_ascii=True,
        separators=(",", ":"),
    ).encode()
    return f"{kind}_{hashlib.sha256(encoded).hexdigest()[:24]}"


def _root_map(links: list[dict[str, Any]], link_type: str) -> dict[str, str]:
    parents = {
        link["source_observation_id"]: link["target_observation_id"]
        for link in links
        if link["link_type"] == link_type
    }

    def root(item: str) -> str:
        visited: set[str] = set()
        current = item
        while current in parents:
            if current in visited:
                raise ValueError(f"cyclic {link_type} link at {current}")
            visited.add(current)
            current = parents[current]
        return current

    return {item: root(item) for item in parents}


def _claim_status(observation: dict[str, Any]) -> str:
    if observation["temporal_status"] == "past":
        return "historical"
    if (
        observation["temporal_status"] == "current"
        and observation["explicitness"] == "explicit"
    ):
        return "current"
    return "uncertain"


def _finalize(rows: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    finalized: list[dict[str, Any]] = []
    for row in rows.values():
        item = deepcopy(row)
        for key in (
            "supporting_observation_ids",
            "contradicting_observation_ids",
            "mention_observation_ids",
            "aliases",
        ):
            if key in item:
                item[key] = sorted(set(item[key]))
        finalized.append(item)
    return sorted(finalized, key=lambda item: item["id"])


def build_projections(case: dict[str, Any]) -> dict[str, Any]:
    """Build a semantic projection snapshot without reading or writing runtime state."""

    all_observations = sorted(
        deepcopy(case["observations"]),
        key=lambda item: (item["observed_at_ms"], item["observation_id"]),
    )
    observations = [
        item for item in all_observations if item["admission"] in PROJECTABLE_ADMISSIONS
    ]
    ignored = sorted(
        item["observation_id"]
        for item in all_observations
        if item["admission"] not in PROJECTABLE_ADMISSIONS
    )
    by_id = {item["observation_id"]: item for item in observations}
    links = case.get("accepted_links", [])

    claims: dict[str, dict[str, Any]] = {}
    current_single_by_key: dict[str, str] = {}
    claim_by_signature: dict[tuple[str, str, str], str] = {}
    for observation in observations:
        predicate = observation["predicate"]
        if predicate not in CLAIM_PREDICATES:
            continue
        normalized = observation["normalized_value"].casefold()
        cardinality = "single" if predicate in SINGLE_CARDINALITY else "multi"
        base_state_key = f"{observation['subject_key']}:{predicate}"
        state_key = base_state_key if cardinality == "single" else f"{base_state_key}:{normalized}"
        status = _claim_status(observation)
        current_id = current_single_by_key.get(base_state_key)
        if cardinality == "single" and status == "current" and current_id is not None:
            current = claims[current_id]
            if current["normalized_value"] == normalized:
                current["supporting_observation_ids"].append(observation["observation_id"])
                current["confidence"] = max(current["confidence"], observation["confidence"])
                continue
            claim_by_signature.pop((current["state_key"], current["normalized_value"], "current"), None)
            current["status"] = "historical"
            current["valid_until_ms"] = observation["observed_at_ms"]
            current["contradicting_observation_ids"].append(observation["observation_id"])
            claim_by_signature[(current["state_key"], current["normalized_value"], "historical")] = current_id
        signature = (state_key, normalized, status)
        existing_id = claim_by_signature.get(signature)
        if existing_id is not None:
            existing = claims[existing_id]
            existing["supporting_observation_ids"].append(observation["observation_id"])
            existing["confidence"] = max(existing["confidence"], observation["confidence"])
            continue
        claim_id = _stable_id("claim", state_key, normalized, observation["observation_id"])
        claims[claim_id] = {
            "id": claim_id,
            "state_key": state_key,
            "cardinality": cardinality,
            "predicate": predicate,
            "value": observation["normalized_value"],
            "normalized_value": normalized,
            "statement": observation["statement"],
            "status": status,
            "valid_from_ms": observation["event_start_at_ms"]
            or observation["observed_at_ms"],
            "valid_until_ms": None,
            "confidence": observation["confidence"],
            "primary_observation_id": observation["observation_id"],
            "supporting_observation_ids": [observation["observation_id"]],
            "contradicting_observation_ids": [],
        }
        claim_by_signature[signature] = claim_id
        if cardinality == "single" and status == "current":
            current_single_by_key[base_state_key] = claim_id

    episode_roots = _root_map(links, "episode_equivalent")
    episodes: dict[str, dict[str, Any]] = {}
    episode_by_observation: dict[str, str] = {}
    for observation in observations:
        if observation["predicate"] not in EPISODE_PREDICATES:
            continue
        root = episode_roots.get(observation["observation_id"], observation["observation_id"])
        if root not in by_id:
            raise ValueError(f"episode link target is not projectable: {root}")
        episode_id = _stable_id("episode", root)
        episode_by_observation[observation["observation_id"]] = episode_id
        if episode_id not in episodes:
            primary = by_id[root]
            resolution = (
                "uncertain"
                if primary["temporal_status"] == "uncertain"
                else "unresolved"
                if primary["temporal_status"] in {"current", "future"}
                else "resolved"
            )
            episodes[episode_id] = {
                "id": episode_id,
                "primary_observation_id": root,
                "event_statement": primary["statement"],
                "normalized_value": primary["normalized_value"].casefold(),
                "resolution_state": resolution,
                "outcome": None,
                "event_start_at_ms": primary["event_start_at_ms"],
                "user_assessment": primary["user_assessment"],
                "affect": primary["affect"],
                "confidence": primary["confidence"],
                "supporting_observation_ids": [],
            }
        episode = episodes[episode_id]
        episode["supporting_observation_ids"].append(observation["observation_id"])
        episode["confidence"] = max(episode["confidence"], observation["confidence"])
        if observation["predicate"] == "event_outcome":
            episode["outcome"] = observation["normalized_value"]
            episode["resolution_state"] = "resolved"

    threads: dict[str, dict[str, Any]] = {}
    thread_by_observation: dict[str, str] = {}
    for observation in observations:
        if observation["predicate"] not in THREAD_PREDICATES:
            continue
        thread_id = _stable_id("thread", observation["observation_id"])
        expected_at = observation["event_start_at_ms"]
        status = "due" if expected_at is not None and expected_at <= case["now_ms"] else "open"
        threads[thread_id] = {
            "id": thread_id,
            "primary_observation_id": observation["observation_id"],
            "thread_kind": (
                "assistant_commitment"
                if observation["predicate"] == "assistant_commitment"
                else "expected_result"
            ),
            "statement": observation["statement"],
            "status": status,
            "expected_start_at_ms": expected_at,
            "resolved_at_ms": None,
            "confidence": observation["confidence"],
            "supporting_observation_ids": [observation["observation_id"]],
        }
        thread_by_observation[observation["observation_id"]] = thread_id
    for link in links:
        if link["link_type"] != "thread_outcome":
            continue
        source_id = link["source_observation_id"]
        target_id = link["target_observation_id"]
        thread_id = thread_by_observation.get(target_id)
        source = by_id.get(source_id)
        if thread_id is None or source is None:
            raise ValueError(f"thread outcome link is not projectable: {link['link_id']}")
        thread = threads[thread_id]
        thread["status"] = "resolved"
        thread["resolved_at_ms"] = source["observed_at_ms"]
        thread["supporting_observation_ids"].append(source_id)

    entity_roots = _root_map(links, "entity_equivalent")
    entities: dict[str, dict[str, Any]] = {}
    entity_by_observation: dict[str, str] = {}
    relations: dict[str, dict[str, Any]] = {}
    relation_observations = [
        item
        for item in observations
        if item["predicate"] in RELATION_FAMILIES and item["target_entity"] is not None
    ]
    if relation_observations:
        user_id = _stable_id("entity", "user")
        entities[user_id] = {
            "id": user_id,
            "entity_type": "user",
            "primary_observation_id": relation_observations[0]["observation_id"],
            "aliases": ["user"],
            "mention_observation_ids": [
                item["observation_id"] for item in relation_observations
            ],
        }
        for observation in relation_observations:
            observation_id = observation["observation_id"]
            root = entity_roots.get(observation_id, observation_id)
            if root not in by_id or by_id[root]["target_entity"] is None:
                raise ValueError(f"entity link target lacks a target entity: {root}")
            target = observation["target_entity"]
            root_target = by_id[root]["target_entity"]
            if target["entity_type"] != root_target["entity_type"]:
                raise ValueError(f"entity link crosses entity types: {observation_id}")
            entity_id = _stable_id("entity", root_target["entity_type"], root)
            entity_by_observation[observation_id] = entity_id
            if entity_id not in entities:
                entities[entity_id] = {
                    "id": entity_id,
                    "entity_type": root_target["entity_type"],
                    "primary_observation_id": root,
                    "aliases": [],
                    "mention_observation_ids": [],
                }
            entity = entities[entity_id]
            entity["aliases"].append(target["normalized_alias"].casefold())
            entity["mention_observation_ids"].append(observation_id)
            family = RELATION_FAMILIES[observation["predicate"]]
            relation_key = (
                f"{user_id}:{family}:{entity_id}:"
                f"{observation['normalized_value'].casefold()}"
            )
            relation_id = _stable_id("relation", relation_key)
            if relation_id not in relations:
                relations[relation_id] = {
                    "id": relation_id,
                    "family": family,
                    "source_entity_id": user_id,
                    "target_entity_id": entity_id,
                    "target_alias": target["normalized_alias"].casefold(),
                    "primary_observation_id": observation_id,
                    "supporting_observation_ids": [],
                }
            relations[relation_id]["supporting_observation_ids"].append(observation_id)

    reflections: dict[str, dict[str, Any]] = {}
    recurrence_groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for observation in observations:
        if observation["predicate"] == "causes_stress" and observation["observation_id"] in episode_by_observation:
            recurrence_groups[observation["normalized_value"].casefold()].append(observation)
    for pattern, support in recurrence_groups.items():
        sessions = {item["session_id"] for item in support}
        times = [item["observed_at_ms"] for item in support]
        if (
            len(support) < RECURRENCE_MIN_EPISODES
            or len(sessions) < RECURRENCE_MIN_SESSIONS
            or max(times) - min(times) < RECURRENCE_MIN_SPAN_MS
        ):
            continue
        support_ids = [item["observation_id"] for item in support]
        reflection_id = _stable_id("reflection", "recurring_pattern", pattern)
        reflections[reflection_id] = {
            "id": reflection_id,
            "reflection_kind": "recurring_pattern",
            "pattern_value": pattern,
            "statement": f"Repeatedly associated with {pattern} across distinct episodes.",
            "status": "uncertain",
            "confidence": min(0.74, min(item["confidence"] for item in support)),
            "primary_observation_id": support_ids[0],
            "supporting_observation_ids": support_ids,
        }

    return {
        "policy_version": POLICY_VERSION,
        "claims": _finalize(claims),
        "episodes": _finalize(episodes),
        "threads": _finalize(threads),
        "entities": _finalize(entities),
        "relations": _finalize(relations),
        "reflections": _finalize(reflections),
        "ignored_observation_ids": ignored,
        "entity_by_observation": dict(sorted(entity_by_observation.items())),
    }
